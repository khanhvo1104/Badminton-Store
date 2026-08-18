-- TASK-037: CMS inventory explorer + atomic adjustments with immutable history.
--
-- list_cms_inventory is SECURITY INVOKER so existing inventory/variant/product
-- RLS and column grants still apply. It never selects cost_price or barcode.
--
-- adjust_cms_inventory is SECURITY DEFINER because authenticated INSERT on
-- inventory_history is closed. It authorizes via public.is_staff_or_admin(),
-- uses auth.uid() as actor, empty search_path, and fixed SQL. Inventory update
-- and history insert share one transaction.

create table public.inventory_history (
  id uuid primary key default gen_random_uuid(),
  variant_id uuid not null
    references public.product_variants (id) on delete restrict,
  actor_id uuid not null
    references public.profiles (id) on delete restrict,
  operation text not null,
  reason text not null,
  note text,
  quantity_on_hand_before integer not null,
  quantity_on_hand_after integer not null,
  quantity_reserved_before integer not null,
  quantity_reserved_after integer not null,
  reorder_level_before integer not null,
  reorder_level_after integer not null,
  allow_backorder_before boolean not null,
  allow_backorder_after boolean not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint inventory_history_operation_check
    check (operation in (
      'add_stock',
      'remove_stock',
      'set_on_hand',
      'set_reorder_level',
      'set_allow_backorder'
    )),
  constraint inventory_history_reason_check
    check (char_length(btrim(reason)) between 1 and 80),
  constraint inventory_history_note_check
    check (
      note is null
      or char_length(btrim(note)) between 1 and 500
    ),
  constraint inventory_history_quantities_nonneg_check
    check (
      quantity_on_hand_before >= 0
      and quantity_on_hand_after >= 0
      and quantity_reserved_before >= 0
      and quantity_reserved_after >= 0
      and reorder_level_before >= 0
      and reorder_level_after >= 0
    ),
  constraint inventory_history_reserved_unchanged_check
    check (quantity_reserved_before = quantity_reserved_after)
);

comment on table public.inventory_history is
  'Immutable per-variant inventory adjustments. Staff/admin SELECT only. '
  'Direct authenticated INSERT/UPDATE/DELETE are closed; writes happen only '
  'through public.adjust_cms_inventory.';

create index inventory_history_variant_created_idx
  on public.inventory_history (variant_id, created_at desc, id desc);

alter table public.inventory_history enable row level security;

create policy inventory_history_staff_select
  on public.inventory_history for select
  to authenticated
  using (public.is_staff_or_admin());

create or replace function public.prevent_inventory_history_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception 'inventory_history is immutable'
    using errcode = '55000';
end;
$$;

comment on function public.prevent_inventory_history_mutation() is
  'Blocks UPDATE and DELETE on inventory_history. SECURITY INVOKER, empty '
  'search_path. EXECUTE revoked from PUBLIC/anon/authenticated; granted to '
  'service_role only. Invoked solely by inventory_history_prevent_mutation.';

revoke all on function public.prevent_inventory_history_mutation() from public;
revoke all on function public.prevent_inventory_history_mutation() from anon;
revoke all on function public.prevent_inventory_history_mutation() from authenticated;
revoke all on function public.prevent_inventory_history_mutation() from service_role;
grant execute on function public.prevent_inventory_history_mutation()
  to service_role;

create trigger inventory_history_prevent_mutation
before update or delete on public.inventory_history
for each row
execute function public.prevent_inventory_history_mutation();

revoke all on table public.inventory_history
  from public, anon, authenticated;
grant select on table public.inventory_history to authenticated;
grant all on table public.inventory_history to service_role;

create or replace function public.list_cms_inventory(
  p_search text default '',
  p_stock text default 'all',
  p_sort text default 'updated_desc',
  p_offset integer default 0,
  p_limit integer default 20
)
returns table (
  variant_id uuid,
  product_id uuid,
  product_name text,
  variant_name text,
  sku text,
  quantity_on_hand integer,
  quantity_reserved integer,
  quantity_available integer,
  reorder_level integer,
  allow_backorder boolean,
  stock_state text,
  updated_at timestamp with time zone,
  filtered_count integer
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_search_raw text;
  v_literal text;
  v_none_match boolean;
  v_stock text;
  v_sort text;
  v_offset integer;
  v_limit integer;
begin
  if not public.is_staff_or_admin() then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  v_search_raw := pg_catalog.left(pg_catalog.btrim(coalesce(p_search, '')), 80);
  v_literal := pg_catalog.replace(
    pg_catalog.replace(
      pg_catalog.replace(v_search_raw, '\', ''),
      '%',
      ''
    ),
    '_',
    ''
  );
  v_none_match := v_search_raw <> '' and v_literal = '';

  v_stock := coalesce(p_stock, 'all');
  if v_stock not in ('all', 'in_stock', 'low_stock', 'out_of_stock', 'missing')
  then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_sort := coalesce(p_sort, 'updated_desc');
  if v_sort not in (
    'updated_desc',
    'updated_asc',
    'product_asc',
    'product_desc',
    'sku_asc',
    'sku_desc',
    'available_asc',
    'available_desc',
    'on_hand_desc',
    'on_hand_asc'
  ) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_offset is null or p_offset < 0 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;
  v_offset := p_offset;

  if p_limit is null or p_limit < 1 or p_limit > 50 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;
  v_limit := p_limit;

  return query
  with sourced as (
    select
      variant_row.id as variant_id,
      variant_row.product_id,
      product_row.name as product_name,
      variant_row.name as variant_name,
      variant_row.sku,
      inventory_row.quantity_on_hand,
      inventory_row.quantity_reserved,
      case
        when inventory_row.variant_id is null then null
        else greatest(
          inventory_row.quantity_on_hand - inventory_row.quantity_reserved,
          0
        )
      end as quantity_available,
      inventory_row.reorder_level,
      inventory_row.allow_backorder,
      case
        when inventory_row.variant_id is null then 'missing'
        when greatest(
          inventory_row.quantity_on_hand - inventory_row.quantity_reserved,
          0
        ) = 0 then 'out_of_stock'
        when greatest(
          inventory_row.quantity_on_hand - inventory_row.quantity_reserved,
          0
        ) <= inventory_row.reorder_level then 'low_stock'
        else 'in_stock'
      end as stock_state,
      (
        inventory_row.variant_id is not null
        and greatest(
          inventory_row.quantity_on_hand - inventory_row.quantity_reserved,
          0
        ) <= inventory_row.reorder_level
      ) as is_low_stock,
      coalesce(inventory_row.updated_at, product_row.updated_at) as updated_at
    from public.product_variants as variant_row
    inner join public.products as product_row
      on product_row.id = variant_row.product_id
    left join public.inventory as inventory_row
      on inventory_row.variant_id = variant_row.id
  ),
  filtered as (
    select sourced.*
    from sourced
    where not v_none_match
      and (
        v_literal = ''
        or pg_catalog.strpos(
          pg_catalog.lower(sourced.product_name),
          pg_catalog.lower(v_literal)
        ) > 0
        or pg_catalog.strpos(
          pg_catalog.lower(coalesce(sourced.variant_name, '')),
          pg_catalog.lower(v_literal)
        ) > 0
        or pg_catalog.strpos(
          pg_catalog.lower(sourced.sku),
          pg_catalog.lower(v_literal)
        ) > 0
      )
      and (
        v_stock = 'all'
        or (v_stock = 'missing' and sourced.stock_state = 'missing')
        or (v_stock = 'low_stock' and sourced.is_low_stock)
        or (
          v_stock = 'in_stock'
          and coalesce(sourced.quantity_available, 0) > 0
        )
        or (
          v_stock = 'out_of_stock'
          and sourced.stock_state = 'out_of_stock'
        )
      )
  ),
  page as (
    select filtered.*
    from filtered
    order by
      case when v_sort = 'updated_desc' then filtered.updated_at end desc nulls last,
      case when v_sort = 'updated_asc' then filtered.updated_at end asc nulls last,
      case when v_sort = 'product_asc' then filtered.product_name end asc,
      case when v_sort = 'product_desc' then filtered.product_name end desc,
      case when v_sort = 'sku_asc' then filtered.sku end asc,
      case when v_sort = 'sku_desc' then filtered.sku end desc,
      case when v_sort = 'available_asc' then filtered.quantity_available end asc nulls last,
      case when v_sort = 'available_desc' then filtered.quantity_available end desc nulls last,
      case when v_sort = 'on_hand_asc' then filtered.quantity_on_hand end asc nulls last,
      case when v_sort = 'on_hand_desc' then filtered.quantity_on_hand end desc nulls last,
      filtered.variant_id asc
    offset v_offset
    limit v_limit
  )
  select
    page.variant_id,
    page.product_id,
    page.product_name,
    page.variant_name,
    page.sku,
    page.quantity_on_hand,
    page.quantity_reserved,
    page.quantity_available,
    page.reorder_level,
    page.allow_backorder,
    page.stock_state,
    page.updated_at,
    counted.filtered_count
  from (
    select pg_catalog.count(*)::integer as filtered_count
    from filtered
  ) as counted
  left join page on true;
end;
$$;

comment on function public.list_cms_inventory(
  text, text, text, integer, integer
) is
  'CMS inventory explorer page. SECURITY INVOKER, STABLE, empty search_path. '
  'Authorizes active trusted profiles.role staff/admin via is_staff_or_admin(). '
  'Searches product name, variant name, and SKU with a wildcard-stripped '
  'literal. Filters and sorts with a fixed CASE contract and variant_id '
  'tie-breaker, then applies offset/limit. Never selects cost_price or barcode. '
  'EXECUTE granted to authenticated and service_role only.';

revoke all on function public.list_cms_inventory(
  text, text, text, integer, integer
) from public;
revoke all on function public.list_cms_inventory(
  text, text, text, integer, integer
) from anon;
revoke all on function public.list_cms_inventory(
  text, text, text, integer, integer
) from authenticated;
revoke all on function public.list_cms_inventory(
  text, text, text, integer, integer
) from service_role;

grant execute on function public.list_cms_inventory(
  text, text, text, integer, integer
) to authenticated, service_role;

drop function if exists public.adjust_cms_inventory(
  uuid, text, integer, boolean, text, text
);

create function public.adjust_cms_inventory(
  p_variant_id uuid,
  p_operation text,
  p_quantity integer,
  p_allow_backorder boolean,
  p_reason text,
  p_note text
)
returns table (
  variant_id uuid
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_exists uuid;
  v_reason text;
  v_note text;
  v_on_hand integer;
  v_reserved integer;
  v_reorder integer;
  v_backorder boolean;
  v_new_on_hand integer;
  v_new_reorder integer;
  v_new_backorder boolean;
  v_max integer := 2147483647;
begin
  if not public.is_staff_or_admin() then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  v_actor := auth.uid();
  if v_actor is null then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  if p_variant_id is null or p_operation is null or p_reason is null then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_operation not in (
    'add_stock',
    'remove_stock',
    'set_on_hand',
    'set_reorder_level',
    'set_allow_backorder'
  ) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_operation = 'set_allow_backorder' then
    if p_allow_backorder is null or p_quantity is not null then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
  else
    if p_allow_backorder is not null or p_quantity is null then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
  end if;

  v_reason := pg_catalog.lower(pg_catalog.btrim(p_reason));
  if v_reason not in (
    'received',
    'returned',
    'damaged',
    'lost',
    'count_correction',
    'other'
  ) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_note := nullif(pg_catalog.btrim(coalesce(p_note, '')), '');
  if v_note is not null then
    v_note := pg_catalog.regexp_replace(v_note, '[[:space:]]+', ' ', 'g');
    if pg_catalog.char_length(v_note) > 500 then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    ('x' || pg_catalog.substr(pg_catalog.md5(p_variant_id::text), 1, 16))::bit(64)::bigint
  );

  select variant_row.id
  into v_exists
  from public.product_variants as variant_row
  where variant_row.id = p_variant_id;

  if v_exists is null then
    raise exception 'not found'
      using errcode = 'P0002';
  end if;

  select
    inventory_row.quantity_on_hand,
    inventory_row.quantity_reserved,
    inventory_row.reorder_level,
    inventory_row.allow_backorder
  into v_on_hand, v_reserved, v_reorder, v_backorder
  from public.inventory as inventory_row
  where inventory_row.variant_id = p_variant_id
  for update of inventory_row;

  if not found then
    insert into public.inventory (
      variant_id,
      quantity_on_hand,
      quantity_reserved,
      reorder_level,
      allow_backorder
    ) values (
      p_variant_id,
      0,
      0,
      0,
      false
    );

    select
      inventory_row.quantity_on_hand,
      inventory_row.quantity_reserved,
      inventory_row.reorder_level,
      inventory_row.allow_backorder
    into v_on_hand, v_reserved, v_reorder, v_backorder
    from public.inventory as inventory_row
    where inventory_row.variant_id = p_variant_id
    for update of inventory_row;

    if not found then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
  end if;

  v_new_on_hand := v_on_hand;
  v_new_reorder := v_reorder;
  v_new_backorder := v_backorder;

  if p_operation = 'add_stock' then
    if p_quantity < 1 then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
    if v_on_hand::bigint + p_quantity::bigint > v_max then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
    v_new_on_hand := v_on_hand + p_quantity;
  elsif p_operation = 'remove_stock' then
    if p_quantity < 1 then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
    if p_quantity > v_on_hand then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
    v_new_on_hand := v_on_hand - p_quantity;
  elsif p_operation = 'set_on_hand' then
    if p_quantity < 0 then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
    v_new_on_hand := p_quantity;
  elsif p_operation = 'set_reorder_level' then
    if p_quantity < 0 then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
    v_new_reorder := p_quantity;
  else
    v_new_backorder := p_allow_backorder;
  end if;

  if not v_new_backorder and v_reserved > v_new_on_hand then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  update public.inventory as inventory_row
  set
    quantity_on_hand = v_new_on_hand,
    reorder_level = v_new_reorder,
    allow_backorder = v_new_backorder
  where inventory_row.variant_id = p_variant_id
    and inventory_row.quantity_reserved = v_reserved;

  if not found then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  insert into public.inventory_history (
    variant_id,
    actor_id,
    operation,
    reason,
    note,
    quantity_on_hand_before,
    quantity_on_hand_after,
    quantity_reserved_before,
    quantity_reserved_after,
    reorder_level_before,
    reorder_level_after,
    allow_backorder_before,
    allow_backorder_after
  ) values (
    p_variant_id,
    v_actor,
    p_operation,
    v_reason,
    v_note,
    v_on_hand,
    v_new_on_hand,
    v_reserved,
    v_reserved,
    v_reorder,
    v_new_reorder,
    v_backorder,
    v_new_backorder
  );

  return query
  select p_variant_id;
end;
$$;

comment on function public.adjust_cms_inventory(
  uuid, text, integer, boolean, text, text
) is
  'CMS inventory adjustment. SECURITY DEFINER, VOLATILE, empty search_path. '
  'Justified so history INSERT can occur while authenticated INSERT/UPDATE/'
  'DELETE on inventory_history remain closed. Authorizes via is_staff_or_admin() '
  'and records auth.uid() as actor. Locks the variant, creates a missing '
  'inventory row when the variant exists, rejects negatives/overflow and '
  'reserved-invariant violations, and writes inventory plus history in one '
  'transaction. Returns only variant_id. EXECUTE '
  'granted to authenticated and service_role only.';

revoke all on function public.adjust_cms_inventory(
  uuid, text, integer, boolean, text, text
) from public;
revoke all on function public.adjust_cms_inventory(
  uuid, text, integer, boolean, text, text
) from anon;
revoke all on function public.adjust_cms_inventory(
  uuid, text, integer, boolean, text, text
) from authenticated;
revoke all on function public.adjust_cms_inventory(
  uuid, text, integer, boolean, text, text
) from service_role;

grant execute on function public.adjust_cms_inventory(
  uuid, text, integer, boolean, text, text
) to authenticated, service_role;
