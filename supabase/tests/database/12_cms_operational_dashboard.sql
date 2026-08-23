-- Executable regression: CMS operational dashboard RPC (TASK-040).
--
-- Run against an already migrated + seeded disposable local database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/12_cms_operational_dashboard.sql
--
-- Assert only scenario labels, IDs, counts, nullability, and SQLSTATEs —
-- never print JWTs, credentials, or caught internals.

\set ON_ERROR_STOP on
\echo '== CMS operational dashboard regression (TASK-040) =='

begin;

create or replace function pg_temp.dash_insert_user(
  p_user_id uuid,
  p_email text
)
returns void
language plpgsql
as $$
begin
  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000',
    p_user_id,
    'authenticated',
    'authenticated',
    p_email,
    crypt('cms-test-password', gen_salt('bf')),
    timezone('utc', now()),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    timezone('utc', now()),
    timezone('utc', now())
  );
end;
$$;

create or replace function pg_temp.dash_set_auth(p_user_id uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', p_user_id::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', p_user_id::text,
      'role', 'authenticated'
    )::text,
    true
  );
  execute 'set local role authenticated';
end;
$$;

create or replace function pg_temp.dash_clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

create or replace function pg_temp.dash_assert_authz_denied(
  p_label text,
  p_sql text
)
returns void
language plpgsql
as $$
declare
  v_denied boolean := false;
begin
  begin
    execute p_sql;
  exception
    when insufficient_privilege then
      if sqlerrm = 'not authorized' then
        v_denied := true;
      else
        perform pg_temp.dash_clear_auth();
        raise exception 'FAIL: % raised 42501 with unexpected message', p_label;
      end if;
    when others then
      if sqlstate = '42501' and sqlerrm = 'not authorized' then
        v_denied := true;
      else
        perform pg_temp.dash_clear_auth();
        raise exception 'FAIL: % raised unexpected SQLSTATE %', p_label, sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.dash_clear_auth();
    raise exception 'FAIL: % expected authorization denial', p_label;
  end if;
end;
$$;

create or replace function pg_temp.dash_assert_execute_denied(
  p_label text,
  p_sql text
)
returns void
language plpgsql
as $$
begin
  begin
    execute p_sql;
    perform pg_temp.dash_clear_auth();
    raise exception 'FAIL: % unexpectedly succeeded', p_label;
  exception
    when insufficient_privilege then
      null;
  end;
end;
$$;

create or replace function pg_temp.dash_assert_invalid_request(
  p_label text,
  p_sql text
)
returns void
language plpgsql
as $$
declare
  v_invalid boolean := false;
begin
  begin
    execute p_sql;
  exception
    when others then
      if sqlstate = '22023' and sqlerrm = 'invalid request' then
        v_invalid := true;
      else
        perform pg_temp.dash_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_invalid then
    perform pg_temp.dash_clear_auth();
    raise exception 'FAIL: % expected invalid request', p_label;
  end if;
end;
$$;

do $$
declare
  v_staff uuid := 'b4000000-0000-4000-8000-000000000101';
  v_admin uuid := 'b4000000-0000-4000-8000-000000000102';
  v_customer uuid := 'b4000000-0000-4000-8000-000000000103';
  v_inactive uuid := 'b4000000-0000-4000-8000-000000000104';
  v_category uuid := 'b4010000-0000-4000-8000-000000000101';
  v_product uuid := 'b4020000-0000-4000-8000-000000000101';
  v_variant_low uuid := 'b4030000-0000-4000-8000-000000000101';
  v_variant_backorder uuid := 'b4030000-0000-4000-8000-000000000102';
  v_order_vnd uuid := 'b4040000-0000-4000-8000-000000000101';
  v_order_usd uuid := 'b4040000-0000-4000-8000-000000000102';
  v_order_cancel uuid := 'b4040000-0000-4000-8000-000000000103';
  v_order_return uuid := 'b4040000-0000-4000-8000-000000000104';
  v_order_open uuid := 'b4040000-0000-4000-8000-000000000105';
  v_sig text := 'public.get_cms_operational_dashboard(integer)';
  v_rpc text;
  v_proconfig_arr text[];
  v_prosecdef boolean;
  v_provolatile char;
  v_row record;
  v_gross jsonb;
  v_daily jsonb;
  v_low jsonb;
  v_usd_gross numeric;
  v_vnd_gross numeric;
  v_day_count integer;
  v_low_count integer;
  v_def text;
  v_gross_codes text[];
  v_daily_codes text[];
  v_first_usd_date text;
  v_last_usd_date text;
begin
  perform pg_temp.dash_insert_user(v_staff, 'dash-staff@example.invalid');
  perform pg_temp.dash_insert_user(v_admin, 'dash-admin@example.invalid');
  perform pg_temp.dash_insert_user(v_customer, 'dash-customer@example.invalid');
  perform pg_temp.dash_insert_user(v_inactive, 'dash-inactive@example.invalid');

  update public.profiles
  set role = 'staff', full_name = 'Dash Staff', is_active = true
  where id = v_staff;
  update public.profiles
  set role = 'admin', full_name = 'Dash Admin', is_active = true
  where id = v_admin;
  update public.profiles
  set role = 'customer', full_name = 'Dash Customer', is_active = true
  where id = v_customer;
  update public.profiles
  set role = 'staff', full_name = 'Dash Inactive', is_active = false
  where id = v_inactive;

  insert into public.categories (id, name, slug, sort_order, is_active)
  values (v_category, 'Dash Category', 'dash-category', 400, true);

  insert into public.products (
    id, category_id, name, slug, status, is_featured, published_at
  ) values (
    v_product, v_category, 'Dash Product', 'dash-product',
    'active', false, timezone('utc', now())
  );

  insert into public.product_variants (
    id, product_id, sku, name, price, is_default, is_active, sort_order
  ) values
  (
    v_variant_low, v_product, 'DASH-LOW', 'Low', 100000, true, true, 0
  ),
  (
    v_variant_backorder, v_product, 'DASH-BACK', 'Backorder', 90000, false, true, 1
  );

  insert into public.inventory (
    variant_id, quantity_on_hand, quantity_reserved, reorder_level, allow_backorder
  ) values
  (v_variant_low, 4, 3, 2, false),
  (v_variant_backorder, 2, 5, 0, true);

  insert into public.orders (
    id, order_number, user_id, status, currency_code,
    subtotal, discount_total, shipping_fee, grand_total,
    recipient_name, recipient_phone, shipping_address, placed_at
  ) values
  (
    v_order_vnd, 'BDM-DASH-VND', v_customer, 'delivered', 'VND',
    300000, 0, 0, 300000,
    'Recipient VND', '0901111111',
    '{"recipient_name":"Recipient VND","phone_number":"0901111111"}'::jsonb,
    timezone('utc', now()) - interval '1 day'
  ),
  (
    v_order_usd, 'BDM-DASH-USD', v_customer, 'pending', 'USD',
    150, 0, 0, 150,
    'Recipient USD', '0902222222',
    '{"recipient_name":"Recipient USD","phone_number":"0902222222"}'::jsonb,
    timezone('utc', now()) - interval '1 day'
  ),
  (
    v_order_cancel, 'BDM-DASH-CAN', v_customer, 'cancelled', 'VND',
    50000, 0, 0, 50000,
    'Recipient Cancel', '0903333333',
    '{"recipient_name":"Recipient Cancel","phone_number":"0903333333"}'::jsonb,
    timezone('utc', now()) - interval '1 day'
  ),
  (
    v_order_return, 'BDM-DASH-RET', v_customer, 'returned', 'USD',
    75, 0, 0, 75,
    'Recipient Return', '0904444444',
    '{"recipient_name":"Recipient Return","phone_number":"0904444444"}'::jsonb,
    timezone('utc', now()) - interval '1 day'
  ),
  (
    v_order_open, 'BDM-DASH-OPEN', v_customer, 'shipping', 'VND',
    120000, 0, 0, 120000,
    'Recipient Open', '0905555555',
    '{"recipient_name":"Recipient Open","phone_number":"0905555555"}'::jsonb,
    timezone('utc', now()) - interval '2 days'
  );

  select p.provolatile, p.prosecdef, p.proconfig
  into v_provolatile, v_prosecdef, v_proconfig_arr
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_cms_operational_dashboard';
  if v_provolatile is distinct from 's' then
    raise exception 'FAIL: get_cms_operational_dashboard is not STABLE';
  end if;
  if v_prosecdef then
    raise exception 'FAIL: get_cms_operational_dashboard is not SECURITY INVOKER';
  end if;
  if v_proconfig_arr is null
     or not exists (
       select 1
       from unnest(v_proconfig_arr) as cfg(val)
       where cfg.val in ('search_path=', 'search_path=""')
     )
  then
    raise exception 'FAIL: get_cms_operational_dashboard search_path is not empty';
  end if;

  select pg_catalog.pg_get_functiondef(p.oid)
  into v_def
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_cms_operational_dashboard';

  if v_def is null then
    raise exception 'FAIL: dashboard function definition missing';
  end if;
  if v_def not like '%order_row.status%'
     or v_def not like '%order_row.currency_code%'
     or v_def not like '%order_row.grand_total%'
     or v_def not like '%order_row.placed_at%' then
    raise exception 'FAIL: window_orders missing required non-PII columns';
  end if;
  if v_def like '%order_row.user_id%'
     or v_def like '%order_row.recipient_name%'
     or v_def like '%order_row.shipping_address%'
     or v_def like '%order_row.customer_note%' then
    raise exception 'FAIL: window_orders selects order PII';
  end if;
  if v_def like '%greatest(%inventory_row.quantity_on_hand - inventory_row.quantity_reserved%' then
    raise exception 'FAIL: low_stock availability is clamped instead of signed';
  end if;

  if has_function_privilege('public', v_sig, 'EXECUTE')
     or has_function_privilege('anon', v_sig, 'EXECUTE') then
    raise exception 'FAIL: get_cms_operational_dashboard EXECUTE too broad';
  end if;
  if not has_function_privilege('authenticated', v_sig, 'EXECUTE')
     or not has_function_privilege('service_role', v_sig, 'EXECUTE') then
    raise exception 'FAIL: get_cms_operational_dashboard missing EXECUTE grant';
  end if;

  v_rpc := $q$select * from public.get_cms_operational_dashboard(30)$q$;

  perform set_config('role', 'anon', true);
  perform pg_temp.dash_assert_execute_denied('anon dashboard', v_rpc);
  perform pg_temp.dash_clear_auth();

  perform pg_temp.dash_set_auth(v_customer);
  perform pg_temp.dash_assert_authz_denied('customer dashboard', v_rpc);
  perform pg_temp.dash_clear_auth();

  perform pg_temp.dash_set_auth(v_inactive);
  perform pg_temp.dash_assert_authz_denied('inactive dashboard', v_rpc);
  perform pg_temp.dash_clear_auth();

  perform pg_temp.dash_set_auth(v_staff);
  perform pg_temp.dash_assert_invalid_request(
    'invalid range',
    $q$select * from public.get_cms_operational_dashboard(14)$q$
  );

  select *
  into v_row
  from public.get_cms_operational_dashboard(7) as dashboard;

  if v_row.range_days <> 7 then
    raise exception 'FAIL: dashboard range_days mismatch';
  end if;
  if v_row.total_orders < 5 then
    raise exception 'FAIL: dashboard total_orders too low';
  end if;
  if v_row.delivered_orders < 1 then
    raise exception 'FAIL: dashboard delivered_orders too low';
  end if;
  if v_row.open_fulfillment_count < 2 then
    raise exception 'FAIL: dashboard open_fulfillment_count too low';
  end if;

  v_gross := v_row.gross_order_value_by_currency;
  select entry.gross_order_value
  into v_usd_gross
  from jsonb_to_recordset(v_gross) as entry(
    currency_code text,
    gross_order_value numeric
  )
  where entry.currency_code = 'USD';
  select entry.gross_order_value
  into v_vnd_gross
  from jsonb_to_recordset(v_gross) as entry(
    currency_code text,
    gross_order_value numeric
  )
  where entry.currency_code = 'VND';

  if v_usd_gross is distinct from 150 then
    raise exception 'FAIL: USD gross_order_value mixed or miscomputed';
  end if;
  if v_vnd_gross is distinct from 420000 then
    raise exception 'FAIL: VND gross_order_value mixed or miscomputed';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(v_gross) as entry(
      currency_code text,
      gross_order_value numeric
    )
    where entry.currency_code not in ('USD', 'VND')
  ) then
    raise exception 'FAIL: unexpected currency in gross_order_value_by_currency';
  end if;

  select coalesce(array_agg(entry.currency_code order by entry.currency_code), '{}')
  into v_gross_codes
  from jsonb_to_recordset(v_gross) as entry(
    currency_code text,
    gross_order_value numeric
  );

  v_daily := v_row.daily_series_by_currency;

  select coalesce(array_agg(currency_block.currency_code order by currency_block.currency_code), '{}')
  into v_daily_codes
  from jsonb_to_recordset(v_daily) as currency_block(
    currency_code text,
    series jsonb
  );

  if v_gross_codes is distinct from v_daily_codes then
    raise exception 'FAIL: gross and daily currency sets mismatch';
  end if;

  select jsonb_array_length(currency_block.series)
  into v_day_count
  from jsonb_to_recordset(v_daily) as currency_block(
    currency_code text,
    series jsonb
  )
  where currency_block.currency_code = 'USD';

  if v_day_count <> 8 then
    raise exception 'FAIL: USD daily series not zero-filled for 7-day window';
  end if;

  select point.date
  into v_first_usd_date
  from jsonb_to_recordset(v_daily) as currency_block(
    currency_code text,
    series jsonb
  )
  cross join lateral jsonb_to_recordset(currency_block.series) as point(
    date text,
    order_count integer,
    gross_order_value numeric
  )
  where currency_block.currency_code = 'USD'
  order by point.date asc
  limit 1;

  select point.date
  into v_last_usd_date
  from jsonb_to_recordset(v_daily) as currency_block(
    currency_code text,
    series jsonb
  )
  cross join lateral jsonb_to_recordset(currency_block.series) as point(
    date text,
    order_count integer,
    gross_order_value numeric
  )
  where currency_block.currency_code = 'USD'
  order by point.date desc
  limit 1;

  if v_first_usd_date is distinct from to_char((v_row.window_start at time zone 'UTC')::date, 'YYYY-MM-DD')
     or v_last_usd_date is distinct from to_char((v_row.window_end at time zone 'UTC')::date, 'YYYY-MM-DD') then
    raise exception 'FAIL: USD daily series endpoints mismatch window UTC dates';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(v_daily) as currency_block(
      currency_code text,
      series jsonb
    )
    cross join lateral jsonb_to_recordset(currency_block.series) as point(
      date text,
      order_count integer,
      gross_order_value numeric
    )
    where currency_block.currency_code = 'USD'
      and point.date = to_char((timezone('utc', now()) - interval '1 day')::date, 'YYYY-MM-DD')
      and point.gross_order_value <> 150
  ) then
    raise exception 'FAIL: USD daily gross miscomputed';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(v_daily) as currency_block(
      currency_code text,
      series jsonb
    )
    cross join lateral jsonb_to_recordset(currency_block.series) as point(
      date text,
      order_count integer,
      gross_order_value numeric
    )
    where currency_block.currency_code = 'VND'
      and point.date = to_char((timezone('utc', now()) - interval '1 day')::date, 'YYYY-MM-DD')
      and point.gross_order_value <> 300000
  ) then
    raise exception 'FAIL: VND daily gross miscomputed';
  end if;

  v_low := v_row.low_stock_variants;
  v_low_count := jsonb_array_length(v_low);
  if v_low_count < 1 or v_low_count > 10 then
    raise exception 'FAIL: low_stock_variants not bounded';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(v_low) as entry(
      variant_id uuid,
      product_id uuid,
      product_name text,
      variant_name text,
      sku text,
      quantity_on_hand integer,
      quantity_reserved integer,
      quantity_available integer,
      reorder_level integer,
      allow_backorder boolean
    )
    where entry.variant_id = v_variant_low
      and entry.quantity_available <> 1
  ) then
    raise exception 'FAIL: low_stock available quantity mismatch';
  end if;

  if not exists (
    select 1
    from jsonb_to_recordset(v_low) as entry(
      variant_id uuid,
      product_id uuid,
      product_name text,
      variant_name text,
      sku text,
      quantity_on_hand integer,
      quantity_reserved integer,
      quantity_available integer,
      reorder_level integer,
      allow_backorder boolean
    )
    where entry.variant_id = v_variant_backorder
      and entry.quantity_on_hand = 2
      and entry.quantity_reserved = 5
      and entry.quantity_available = -3
      and entry.reorder_level = 0
  ) then
    raise exception 'FAIL: signed negative availability not surfaced';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(v_low) as entry(
      variant_id uuid,
      product_id uuid,
      product_name text,
      variant_name text,
      sku text,
      quantity_on_hand integer,
      quantity_reserved integer,
      quantity_available integer,
      reorder_level integer,
      allow_backorder boolean
    )
    where entry.quantity_available <> (
      entry.quantity_on_hand - entry.quantity_reserved
    )
  ) then
    raise exception 'FAIL: low_stock available is not on_hand - reserved';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(v_low) as entry(
      variant_id uuid,
      product_id uuid,
      product_name text,
      variant_name text,
      sku text,
      quantity_on_hand integer,
      quantity_reserved integer,
      quantity_available integer,
      reorder_level integer,
      allow_backorder boolean
    )
    where entry.quantity_available > entry.reorder_level
  ) then
    raise exception 'FAIL: low_stock row exceeds reorder level';
  end if;

  if v_gross::text ilike '%recipient%'
     or v_gross::text ilike '%user_id%'
     or v_low::text ilike '%cost_price%' then
    raise exception 'FAIL: dashboard payload exposed forbidden fields';
  end if;

  perform pg_temp.dash_clear_auth();

  perform pg_temp.dash_set_auth(v_admin);
  perform pg_temp.dash_assert_invalid_request(
    'admin invalid range',
    $q$select * from public.get_cms_operational_dashboard(0)$q$
  );
  perform pg_temp.dash_clear_auth();
end;
$$;

rollback;

\echo 'PASS: CMS operational dashboard regression (TASK-040)'
