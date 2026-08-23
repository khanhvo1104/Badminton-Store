-- TASK-040: CMS operational dashboard metrics.
--
-- get_cms_operational_dashboard is SECURITY INVOKER so existing orders,
-- inventory, and catalog RLS/grants still apply. window_orders selects only
-- status, currency_code, grand_total, and placed_at. Monetary metrics are
-- grouped by currency_code; no cross-currency aggregation.

create or replace function public.get_cms_operational_dashboard(
  p_range_days integer default 30
)
returns table (
  range_days integer,
  window_start timestamptz,
  window_end timestamptz,
  total_orders integer,
  gross_order_value_by_currency jsonb,
  delivered_orders integer,
  open_fulfillment_count integer,
  status_breakdown jsonb,
  daily_series_by_currency jsonb,
  low_stock_variants jsonb
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_range_days integer;
  v_window_end timestamptz;
  v_window_start timestamptz;
  v_currency_count integer;
begin
  if not public.is_staff_or_admin() then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  v_range_days := coalesce(p_range_days, 30);
  if v_range_days not in (7, 30, 90) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_window_end := timezone('utc', now());
  v_window_start := v_window_end - (v_range_days || ' days')::interval;

  select pg_catalog.count(distinct order_row.currency_code)
  into v_currency_count
  from public.orders as order_row
  where order_row.placed_at >= v_window_start
    and order_row.placed_at <= v_window_end;

  if v_currency_count > 20 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  return query
  with params as (
    select
      v_range_days as range_days,
      v_window_start as window_start,
      v_window_end as window_end
  ),
  window_orders as (
    select
      order_row.status,
      order_row.currency_code,
      order_row.grand_total,
      order_row.placed_at
    from public.orders as order_row, params
    where order_row.placed_at >= params.window_start
      and order_row.placed_at <= params.window_end
  ),
  gross_by_currency as (
    select
      window_orders.currency_code,
      coalesce(
        pg_catalog.sum(window_orders.grand_total),
        0
      )::numeric(14, 2) as gross_order_value
    from window_orders
    where window_orders.status not in ('cancelled', 'returned')
    group by window_orders.currency_code
    order by window_orders.currency_code asc
  ),
  status_counts as (
    select
      window_orders.status,
      pg_catalog.count(*)::integer as order_count
    from window_orders
    group by window_orders.status
  ),
  status_breakdown_payload as (
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'status', status_axis.status,
          'order_count', coalesce(status_counts.order_count, 0)
        )
        order by status_axis.sort_order
      ),
      '[]'::jsonb
    ) as payload
    from (
      values
        (1, 'pending'),
        (2, 'confirmed'),
        (3, 'preparing'),
        (4, 'shipping'),
        (5, 'delivered'),
        (6, 'cancelled'),
        (7, 'returned')
    ) as status_axis(sort_order, status)
    left join status_counts
      on status_counts.status = status_axis.status
  ),
  currencies as (
    select distinct window_orders.currency_code
    from window_orders
    order by window_orders.currency_code asc
  ),
  days as (
    select generate_series(
      (select (params.window_start at time zone 'UTC')::date from params),
      (select (params.window_end at time zone 'UTC')::date from params),
      interval '1 day'
    )::date as day
  ),
  daily_agg as (
    select
      window_orders.currency_code,
      (window_orders.placed_at at time zone 'UTC')::date as day,
      pg_catalog.count(*)::integer as order_count,
      coalesce(
        pg_catalog.sum(window_orders.grand_total)
          filter (
            where window_orders.status not in ('cancelled', 'returned')
          ),
        0
      )::numeric(14, 2) as gross_order_value
    from window_orders
    group by window_orders.currency_code, 2
  ),
  daily_series_payload as (
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'currency_code', currencies.currency_code,
          'series', (
            select coalesce(
              pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                  'date', pg_catalog.to_char(days.day, 'YYYY-MM-DD'),
                  'order_count', coalesce(daily_agg.order_count, 0),
                  'gross_order_value', coalesce(daily_agg.gross_order_value, 0)
                )
                order by days.day asc
              ),
              '[]'::jsonb
            )
            from days
            left join daily_agg
              on daily_agg.currency_code = currencies.currency_code
             and daily_agg.day = days.day
          )
        )
        order by currencies.currency_code asc
      ),
      '[]'::jsonb
    ) as payload
    from currencies
  ),
  low_stock_ranked as (
    select
      variant_row.id as variant_id,
      variant_row.product_id,
      product_row.name as product_name,
      variant_row.name as variant_name,
      variant_row.sku,
      inventory_row.quantity_on_hand,
      inventory_row.quantity_reserved,
      (
        inventory_row.quantity_on_hand - inventory_row.quantity_reserved
      ) as quantity_available,
      inventory_row.reorder_level,
      inventory_row.allow_backorder
    from public.product_variants as variant_row
    inner join public.products as product_row
      on product_row.id = variant_row.product_id
    inner join public.inventory as inventory_row
      on inventory_row.variant_id = variant_row.id
    where (
      inventory_row.quantity_on_hand - inventory_row.quantity_reserved
    ) <= inventory_row.reorder_level
    order by
      (
        inventory_row.quantity_on_hand - inventory_row.quantity_reserved
      ) asc,
      (
        (
          inventory_row.quantity_on_hand - inventory_row.quantity_reserved
        ) - inventory_row.reorder_level
      ) asc,
      variant_row.sku asc,
      variant_row.id asc
    limit 10
  ),
  low_stock_payload as (
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'variant_id', low_stock_ranked.variant_id,
          'product_id', low_stock_ranked.product_id,
          'product_name', low_stock_ranked.product_name,
          'variant_name', low_stock_ranked.variant_name,
          'sku', low_stock_ranked.sku,
          'quantity_on_hand', low_stock_ranked.quantity_on_hand,
          'quantity_reserved', low_stock_ranked.quantity_reserved,
          'quantity_available', low_stock_ranked.quantity_available,
          'reorder_level', low_stock_ranked.reorder_level,
          'allow_backorder', low_stock_ranked.allow_backorder
        )
        order by
          low_stock_ranked.quantity_available asc,
          (
            low_stock_ranked.quantity_available - low_stock_ranked.reorder_level
          ) asc,
          low_stock_ranked.sku asc,
          low_stock_ranked.variant_id asc
      ),
      '[]'::jsonb
    ) as payload
    from low_stock_ranked
  )
  select
    params.range_days,
    params.window_start,
    params.window_end,
    (
      select pg_catalog.count(*)::integer
      from window_orders
    ) as total_orders,
    (
      select coalesce(
        pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'currency_code', gross_by_currency.currency_code,
            'gross_order_value', gross_by_currency.gross_order_value
          )
          order by gross_by_currency.currency_code asc
        ),
        '[]'::jsonb
      )
      from gross_by_currency
    ) as gross_order_value_by_currency,
    (
      select pg_catalog.count(*)::integer
      from window_orders
      where window_orders.status = 'delivered'
    ) as delivered_orders,
    (
      select pg_catalog.count(*)::integer
      from public.orders as order_row
      where order_row.status in (
        'pending',
        'confirmed',
        'preparing',
        'shipping'
      )
    ) as open_fulfillment_count,
    status_breakdown_payload.payload as status_breakdown,
    daily_series_payload.payload as daily_series_by_currency,
    low_stock_payload.payload as low_stock_variants
  from params
  cross join status_breakdown_payload
  cross join daily_series_payload
  cross join low_stock_payload;
end;
$$;

comment on function public.get_cms_operational_dashboard(integer) is
  'CMS operational dashboard. SECURITY INVOKER, STABLE, empty search_path. '
  'Authorizes active trusted profiles.role staff/admin via is_staff_or_admin(). '
  'Range is 7, 30, or 90 days (default 30) ending at UTC now. window_orders '
  'selects only status, currency_code, grand_total, and placed_at. Count '
  'metrics use placed_at in the window except open_fulfillment_count, which is '
  'the current global backlog in pending/confirmed/preparing/shipping. '
  'gross_order_value excludes cancelled/returned orders and is returned per '
  'currency_code without cross-currency summation; more than 20 currencies in '
  'the window raises invalid request. daily_series_by_currency zero-fills every '
  'UTC day per currency independently. low_stock_variants is bounded to 10 rows '
  'where signed available = on_hand - reserved is <= reorder_level '
  '(allow_backorder still signals). Includes inactive catalog rows when '
  'inventory exists. Never returns cost_price, user_id, shipping/recipient '
  'PII, or customer notes. EXECUTE granted to authenticated and service_role only.';

revoke all on function public.get_cms_operational_dashboard(integer) from public;
revoke all on function public.get_cms_operational_dashboard(integer) from anon;
revoke all on function public.get_cms_operational_dashboard(integer) from authenticated;
revoke all on function public.get_cms_operational_dashboard(integer) from service_role;

grant execute on function public.get_cms_operational_dashboard(integer)
  to authenticated, service_role;
