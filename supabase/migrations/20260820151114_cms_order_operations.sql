-- TASK-039: CMS order list + atomic status transitions.
--
-- list_cms_orders is SECURITY INVOKER so existing orders/order_items RLS and
-- column grants still apply. It never selects protected catalog fields.
--
-- transition_cms_order_status is SECURITY DEFINER because authenticated UPDATE
-- on public.orders is revoked; status changes must go through this RPC only.
-- It authorizes via public.is_staff_or_admin(), uses auth.uid() as actor,
-- empty search_path, row + inventory locks, transition validation, inventory
-- effects, and a single orders UPDATE. History is written exactly once by
-- orders_record_status_history / record_order_status_change. Optional staff
-- notes are stamped onto that trigger-written row in the same transaction
-- (not via client-settable GUCs).

revoke update on table public.orders from authenticated;
grant select, insert on table public.orders to authenticated;

comment on table public.orders is
  'Customer orders. Totals and status are server-trusted; Flutter must not '
  'insert trusted totals directly. shipping_address is an immutable snapshot. '
  'Authenticated callers have SELECT/INSERT only; status transitions go through '
  'public.transition_cms_order_status.';

create or replace function public.list_cms_orders(
  p_search text default '',
  p_status text default 'all',
  p_payment_status text default 'all',
  p_placed_from timestamp with time zone default null,
  p_placed_to timestamp with time zone default null,
  p_sort text default 'placed_desc',
  p_offset integer default 0,
  p_limit integer default 20
)
returns table (
  order_id uuid,
  order_number text,
  status text,
  payment_status text,
  currency_code text,
  grand_total numeric,
  recipient_name text,
  recipient_phone text,
  placed_at timestamp with time zone,
  item_count integer,
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
  v_status text;
  v_payment text;
  v_sort text;
  v_offset integer;
  v_limit integer;
  v_from timestamptz;
  v_to timestamptz;
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

  v_status := coalesce(p_status, 'all');
  if v_status not in (
    'all',
    'pending',
    'confirmed',
    'preparing',
    'shipping',
    'delivered',
    'cancelled',
    'returned'
  ) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_payment := coalesce(p_payment_status, 'all');
  if v_payment not in (
    'all',
    'unpaid',
    'pending',
    'paid',
    'failed',
    'refunded'
  ) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_from := p_placed_from;
  v_to := p_placed_to;
  if v_from is not null and v_to is not null and v_from > v_to then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_sort := coalesce(p_sort, 'placed_desc');
  if v_sort not in (
    'placed_desc',
    'placed_asc',
    'total_desc',
    'total_asc',
    'number_asc',
    'number_desc',
    'status_asc',
    'status_desc'
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
      order_row.id as order_id,
      order_row.order_number,
      order_row.status,
      order_row.payment_status,
      order_row.currency_code,
      order_row.grand_total,
      order_row.recipient_name,
      order_row.recipient_phone,
      order_row.placed_at,
      coalesce(item_stats.item_count, 0)::integer as item_count
    from public.orders as order_row
    left join lateral (
      select pg_catalog.count(*)::integer as item_count
      from public.order_items as item_row
      where item_row.order_id = order_row.id
    ) as item_stats on true
  ),
  filtered as (
    select sourced.*
    from sourced
    where not v_none_match
      and (
        v_literal = ''
        or pg_catalog.strpos(
          pg_catalog.lower(sourced.order_number),
          pg_catalog.lower(v_literal)
        ) > 0
        or pg_catalog.strpos(
          pg_catalog.lower(sourced.recipient_name),
          pg_catalog.lower(v_literal)
        ) > 0
        or pg_catalog.strpos(
          pg_catalog.lower(sourced.recipient_phone),
          pg_catalog.lower(v_literal)
        ) > 0
      )
      and (v_status = 'all' or sourced.status = v_status)
      and (v_payment = 'all' or sourced.payment_status = v_payment)
      and (v_from is null or sourced.placed_at >= v_from)
      and (v_to is null or sourced.placed_at <= v_to)
  ),
  page as (
    select filtered.*
    from filtered
    order by
      case when v_sort = 'placed_desc' then filtered.placed_at end desc nulls last,
      case when v_sort = 'placed_asc' then filtered.placed_at end asc nulls last,
      case when v_sort = 'total_desc' then filtered.grand_total end desc nulls last,
      case when v_sort = 'total_asc' then filtered.grand_total end asc nulls last,
      case when v_sort = 'number_asc' then filtered.order_number end asc,
      case when v_sort = 'number_desc' then filtered.order_number end desc,
      case when v_sort = 'status_asc' then filtered.status end asc,
      case when v_sort = 'status_desc' then filtered.status end desc,
      filtered.order_id asc
    offset v_offset
    limit v_limit
  )
  select
    page.order_id,
    page.order_number,
    page.status,
    page.payment_status,
    page.currency_code,
    page.grand_total,
    page.recipient_name,
    page.recipient_phone,
    page.placed_at,
    page.item_count,
    counted.filtered_count
  from (
    select pg_catalog.count(*)::integer as filtered_count
    from filtered
  ) as counted
  left join page on true;
end;
$$;

comment on function public.list_cms_orders(
  text, text, text, timestamp with time zone, timestamp with time zone,
  text, integer, integer
) is
  'CMS order explorer page. SECURITY INVOKER, STABLE, empty search_path. '
  'Authorizes active trusted profiles.role staff/admin via is_staff_or_admin(). '
  'Searches order number, recipient name, and phone with a wildcard-stripped '
  'literal. Filters status, payment status, and placed date range with fixed '
  'CASE sorts and order_id tie-breaker. Never selects protected catalog fields. '
  'EXECUTE granted to authenticated and service_role only.';

revoke all on function public.list_cms_orders(
  text, text, text, timestamp with time zone, timestamp with time zone,
  text, integer, integer
) from public;
revoke all on function public.list_cms_orders(
  text, text, text, timestamp with time zone, timestamp with time zone,
  text, integer, integer
) from anon;
revoke all on function public.list_cms_orders(
  text, text, text, timestamp with time zone, timestamp with time zone,
  text, integer, integer
) from authenticated;
revoke all on function public.list_cms_orders(
  text, text, text, timestamp with time zone, timestamp with time zone,
  text, integer, integer
) from service_role;

grant execute on function public.list_cms_orders(
  text, text, text, timestamp with time zone, timestamp with time zone,
  text, integer, integer
) to authenticated, service_role;

create or replace function public.transition_cms_order_status(
  p_order_id uuid,
  p_to_status text,
  p_note text default null
)
returns table (
  order_id uuid
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_from_status text;
  v_to_status text;
  v_note text;
  v_history_id uuid;
  v_item record;
  v_reserved integer;
  v_on_hand integer;
  v_needs_release boolean;
  v_needs_consume boolean;
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

  if p_order_id is null or p_to_status is null then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_to_status := pg_catalog.btrim(p_to_status);
  if v_to_status not in (
    'pending',
    'confirmed',
    'preparing',
    'shipping',
    'delivered',
    'cancelled',
    'returned'
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

  select order_row.status
  into v_from_status
  from public.orders as order_row
  where order_row.id = p_order_id
  for update of order_row;

  if not found then
    raise exception 'not found'
      using errcode = 'P0002';
  end if;

  if v_from_status is not distinct from v_to_status then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if not (
    (v_from_status = 'pending' and v_to_status in ('confirmed', 'cancelled'))
    or (v_from_status = 'confirmed' and v_to_status in ('preparing', 'cancelled'))
    or (v_from_status = 'preparing' and v_to_status in ('shipping', 'cancelled'))
    or (v_from_status = 'shipping' and v_to_status = 'delivered')
    or (v_from_status = 'delivered' and v_to_status = 'returned')
  ) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_needs_release := (
    v_to_status = 'cancelled'
    and v_from_status in ('pending', 'confirmed', 'preparing')
  );
  v_needs_consume := (v_to_status = 'delivered');

  if v_needs_release or v_needs_consume then
    if exists (
      select 1
      from public.order_items as item_row
      where item_row.order_id = p_order_id
        and item_row.variant_id is null
    ) then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;

    for v_item in
      select
        item_row.variant_id,
        pg_catalog.sum(item_row.quantity)::integer as quantity
      from public.order_items as item_row
      where item_row.order_id = p_order_id
      group by item_row.variant_id
      order by item_row.variant_id asc
    loop
      select
        inventory_row.quantity_reserved,
        inventory_row.quantity_on_hand
      into v_reserved, v_on_hand
      from public.inventory as inventory_row
      where inventory_row.variant_id = v_item.variant_id
      for update of inventory_row;

      if not found then
        raise exception 'invalid request'
          using errcode = '22023';
      end if;

      if v_reserved < v_item.quantity then
        raise exception 'invalid request'
          using errcode = '22023';
      end if;

      if v_needs_consume and v_on_hand < v_item.quantity then
        raise exception 'invalid request'
          using errcode = '22023';
      end if;

      if v_needs_release then
        update public.inventory as inventory_row
        set quantity_reserved = inventory_row.quantity_reserved - v_item.quantity
        where inventory_row.variant_id = v_item.variant_id
          and inventory_row.quantity_reserved = v_reserved;

        if not found then
          raise exception 'invalid request'
            using errcode = '22023';
        end if;
      else
        update public.inventory as inventory_row
        set
          quantity_reserved = inventory_row.quantity_reserved - v_item.quantity,
          quantity_on_hand = inventory_row.quantity_on_hand - v_item.quantity
        where inventory_row.variant_id = v_item.variant_id
          and inventory_row.quantity_reserved = v_reserved
          and inventory_row.quantity_on_hand = v_on_hand;

        if not found then
          raise exception 'invalid request'
            using errcode = '22023';
        end if;
      end if;
    end loop;
  end if;

  update public.orders as order_row
  set
    status = v_to_status,
    cancelled_at = case
      when v_to_status = 'cancelled' then timezone('utc', now())
      else order_row.cancelled_at
    end
  where order_row.id = p_order_id
    and order_row.status = v_from_status;

  if not found then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  select history_row.id
  into v_history_id
  from public.order_status_history as history_row
  where history_row.order_id = p_order_id
    and history_row.from_status is not distinct from v_from_status
    and history_row.to_status = v_to_status
    and history_row.changed_by is not distinct from v_actor
  order by history_row.created_at desc, history_row.id desc
  limit 1;

  if v_history_id is null then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if v_note is not null then
    update public.order_status_history as history_row
    set note = v_note
    where history_row.id = v_history_id
      and history_row.note is null;
  end if;

  return query
  select p_order_id;
end;
$$;

comment on function public.transition_cms_order_status(
  uuid, text, text
) is
  'CMS order status transition. SECURITY DEFINER, VOLATILE, empty search_path. '
  'Justified because authenticated UPDATE on public.orders is revoked; status '
  'changes must not be client-writable. Authorizes via is_staff_or_admin() and '
  'records auth.uid() as actor. Locks the order row, validates the transition '
  'graph, releases reservations on pre-shipping cancel, consumes reserved and '
  'on-hand on delivered, leaves returned without restock, updates status and '
  'cancelled_at, and relies on orders_record_status_history for exactly one '
  'history row (optional note stamped afterward). Returns only order_id. '
  'EXECUTE granted to authenticated and service_role only.';

revoke all on function public.transition_cms_order_status(
  uuid, text, text
) from public;
revoke all on function public.transition_cms_order_status(
  uuid, text, text
) from anon;
revoke all on function public.transition_cms_order_status(
  uuid, text, text
) from authenticated;
revoke all on function public.transition_cms_order_status(
  uuid, text, text
) from service_role;

grant execute on function public.transition_cms_order_status(
  uuid, text, text
) to authenticated, service_role;

-- Keep trigger helper EXECUTE locked (restate; do not broaden).
revoke all on function public.record_order_status_change() from public;
revoke all on function public.record_order_status_change() from anon;
revoke all on function public.record_order_status_change() from authenticated;
grant execute on function public.record_order_status_change() to service_role;
