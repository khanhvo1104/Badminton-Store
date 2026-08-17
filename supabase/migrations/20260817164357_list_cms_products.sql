-- TASK-034: staff/admin CMS product explorer aggregate read.
--
-- SECURITY INVOKER so existing RLS and column grants still apply. The
-- function never selects cost_price, barcode, or customer fields. Sort is a
-- fixed CASE contract (no dynamic SQL). Search uses a wildcard-stripped
-- literal substring, not a PostgREST filter expression.

create or replace function public.list_cms_products(
  p_search text default '',
  p_category_id uuid default null,
  p_brand_id uuid default null,
  p_status text default null,
  p_stock text default 'all',
  p_sort text default 'updated_desc',
  p_offset integer default 0,
  p_limit integer default 20
)
returns table (
  id uuid,
  category_id uuid,
  brand_id uuid,
  name text,
  slug text,
  status text,
  is_featured boolean,
  published_at timestamp with time zone,
  updated_at timestamp with time zone,
  active_variant_count integer,
  total_variant_count integer,
  min_price numeric,
  max_price numeric,
  total_on_hand integer,
  total_reserved integer,
  total_available integer,
  missing_inventory_count integer,
  has_missing_inventory boolean,
  is_low_stock boolean,
  stock_state text,
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
  v_stock text;
  v_sort text;
  v_offset integer;
  v_limit integer;
begin
  if not public.is_staff_or_admin() then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  v_search_raw := left(btrim(coalesce(p_search, '')), 80);
  v_literal := replace(replace(replace(v_search_raw, '\', ''), '%', ''), '_', '');
  v_none_match := v_search_raw <> '' and v_literal = '';

  if p_status is not null
     and p_status not in ('draft', 'active', 'inactive', 'archived')
  then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;
  v_status := p_status;

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
    'name_asc',
    'name_desc',
    'price_asc',
    'price_desc'
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
  with variant_stats as (
    select
      variant_row.product_id,
      pg_catalog.count(*)::integer as total_variant_count,
      pg_catalog.count(*) filter (
        where variant_row.is_active
      )::integer as active_variant_count,
      pg_catalog.min(variant_row.price) as min_price,
      pg_catalog.max(variant_row.price) as max_price
    from public.product_variants as variant_row
    group by variant_row.product_id
  ),
  inventory_stats as (
    select
      variant_row.product_id,
      pg_catalog.count(*)::integer as inventory_row_count,
      coalesce(
        pg_catalog.sum(inventory_row.quantity_on_hand)::integer,
        0
      ) as total_on_hand,
      coalesce(
        pg_catalog.sum(inventory_row.quantity_reserved)::integer,
        0
      ) as total_reserved,
      coalesce(
        pg_catalog.sum(
          greatest(
            inventory_row.quantity_on_hand - inventory_row.quantity_reserved,
            0
          )
        )::integer,
        0
      ) as total_available,
      pg_catalog.bool_or(
        greatest(
          inventory_row.quantity_on_hand - inventory_row.quantity_reserved,
          0
        ) <= inventory_row.reorder_level
      ) as is_low_stock
    from public.product_variants as variant_row
    inner join public.inventory as inventory_row
      on inventory_row.variant_id = variant_row.id
    group by variant_row.product_id
  ),
  aggregated as (
    select
      product_row.id,
      product_row.category_id,
      product_row.brand_id,
      product_row.name,
      product_row.slug,
      product_row.status,
      product_row.is_featured,
      product_row.published_at,
      product_row.updated_at,
      coalesce(variant_stats.active_variant_count, 0) as active_variant_count,
      coalesce(variant_stats.total_variant_count, 0) as total_variant_count,
      variant_stats.min_price,
      variant_stats.max_price,
      case
        when coalesce(inventory_stats.inventory_row_count, 0) = 0 then null
        else inventory_stats.total_on_hand
      end as total_on_hand,
      case
        when coalesce(inventory_stats.inventory_row_count, 0) = 0 then null
        else inventory_stats.total_reserved
      end as total_reserved,
      case
        when coalesce(inventory_stats.inventory_row_count, 0) = 0 then null
        else inventory_stats.total_available
      end as total_available,
      (
        coalesce(variant_stats.total_variant_count, 0)
        - coalesce(inventory_stats.inventory_row_count, 0)
      ) as missing_inventory_count,
      (
        coalesce(variant_stats.total_variant_count, 0)
        - coalesce(inventory_stats.inventory_row_count, 0)
      ) > 0 as has_missing_inventory,
      case
        when coalesce(inventory_stats.inventory_row_count, 0) = 0 then false
        else coalesce(inventory_stats.is_low_stock, false)
      end as is_low_stock,
      case
        when coalesce(variant_stats.total_variant_count, 0) > 0
          and coalesce(inventory_stats.inventory_row_count, 0) = 0
          then 'missing'
        when coalesce(inventory_stats.inventory_row_count, 0) = 0
          then 'out_of_stock'
        when (
          coalesce(variant_stats.total_variant_count, 0)
          - coalesce(inventory_stats.inventory_row_count, 0)
        ) > 0 then 'missing'
        when inventory_stats.total_available = 0 then 'out_of_stock'
        when inventory_stats.is_low_stock then 'low_stock'
        else 'in_stock'
      end as stock_state
    from public.products as product_row
    left join variant_stats
      on variant_stats.product_id = product_row.id
    left join inventory_stats
      on inventory_stats.product_id = product_row.id
  ),
  filtered as (
    select aggregated.*
    from aggregated
    where not v_none_match
      and (p_category_id is null or aggregated.category_id = p_category_id)
      and (p_brand_id is null or aggregated.brand_id = p_brand_id)
      and (v_status is null or aggregated.status = v_status)
      and (
        v_literal = ''
        or pg_catalog.strpos(
          pg_catalog.lower(aggregated.name),
          pg_catalog.lower(v_literal)
        ) > 0
        or pg_catalog.strpos(
          pg_catalog.lower(aggregated.slug),
          pg_catalog.lower(v_literal)
        ) > 0
      )
      and (
        v_stock = 'all'
        or (v_stock = 'missing' and aggregated.has_missing_inventory)
        or (v_stock = 'low_stock' and aggregated.is_low_stock)
        or (
          v_stock = 'in_stock'
          and coalesce(aggregated.total_available, 0) > 0
        )
        or (
          v_stock = 'out_of_stock'
          and aggregated.stock_state = 'out_of_stock'
        )
      )
  ),
  page as (
    select filtered.*
    from filtered
    order by
      case when v_sort = 'updated_desc' then filtered.updated_at end desc nulls last,
      case when v_sort = 'updated_asc' then filtered.updated_at end asc nulls last,
      case when v_sort = 'name_asc' then filtered.name end asc,
      case when v_sort = 'name_desc' then filtered.name end desc,
      case when v_sort = 'price_asc' then filtered.min_price end asc nulls last,
      case when v_sort = 'price_desc' then filtered.min_price end desc nulls last,
      filtered.id asc
    offset v_offset
    limit v_limit
  )
  select
    page.id,
    page.category_id,
    page.brand_id,
    page.name,
    page.slug,
    page.status,
    page.is_featured,
    page.published_at,
    page.updated_at,
    page.active_variant_count,
    page.total_variant_count,
    page.min_price,
    page.max_price,
    page.total_on_hand,
    page.total_reserved,
    page.total_available,
    page.missing_inventory_count,
    page.has_missing_inventory,
    page.is_low_stock,
    page.stock_state,
    counted.filtered_count
  from (
    select pg_catalog.count(*)::integer as filtered_count
    from filtered
  ) as counted
  left join page on true;
end;
$$;

comment on function public.list_cms_products(
  text, uuid, uuid, text, text, text, integer, integer
) is
  'CMS product explorer page. SECURITY INVOKER, STABLE, empty search_path. '
  'Authorizes active trusted profiles.role staff/admin via is_staff_or_admin(). '
  'Aggregates selling prices and inventory, filters, sorts with a fixed CASE '
  'contract and id tie-breaker, then applies offset/limit. Never selects '
  'cost_price, barcode, or customer fields. EXECUTE granted to authenticated '
  'and service_role only.';

revoke all on function public.list_cms_products(
  text, uuid, uuid, text, text, text, integer, integer
) from public;
revoke all on function public.list_cms_products(
  text, uuid, uuid, text, text, text, integer, integer
) from anon;
revoke all on function public.list_cms_products(
  text, uuid, uuid, text, text, text, integer, integer
) from authenticated;
revoke all on function public.list_cms_products(
  text, uuid, uuid, text, text, text, integer, integer
) from service_role;

grant execute on function public.list_cms_products(
  text, uuid, uuid, text, text, text, integer, integer
) to authenticated, service_role;
