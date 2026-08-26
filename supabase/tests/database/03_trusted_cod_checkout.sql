-- Executable regression: trusted COD checkout RPC (public.checkout_cod).
--
-- Run against an already migrated + seeded disposable local database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/03_trusted_cod_checkout.sql
--
-- Fixtures run inside a transaction and roll back. Do not print tokens,
-- secrets, cost_price values, or full JWT claims.

\echo '== trusted COD checkout regression =='

begin;

-- ---------------------------------------------------------------------------
-- Privilege surface
-- ---------------------------------------------------------------------------
do $$
begin
  if has_function_privilege(
    'public', 'public.checkout_cod(uuid, text)', 'EXECUTE'
  ) then
    raise exception 'FAIL: PUBLIC still has EXECUTE on checkout_cod';
  end if;

  if has_function_privilege(
    'anon', 'public.checkout_cod(uuid, text)', 'EXECUTE'
  ) then
    raise exception 'FAIL: anon has EXECUTE on checkout_cod';
  end if;

  if not has_function_privilege(
    'authenticated', 'public.checkout_cod(uuid, text)', 'EXECUTE'
  ) then
    raise exception 'FAIL: authenticated missing EXECUTE on checkout_cod';
  end if;

  if not has_function_privilege(
    'service_role', 'public.checkout_cod(uuid, text)', 'EXECUTE'
  ) then
    raise exception 'FAIL: service_role missing EXECUTE on checkout_cod';
  end if;

  raise notice 'OK: checkout_cod EXECUTE grants (PUBLIC/anon revoked)';
end $$;

-- Customer order/inventory write surface must remain closed via RLS (table GRANTs
-- may still exist; successful writes must not).
do $$
declare
  v_ok boolean := false;
begin
  begin
    set local role authenticated;
    perform set_config(
      'request.jwt.claims',
      json_build_object(
        'sub', 'a1000000-0000-4000-8000-000000000001',
        'role', 'authenticated'
      )::text,
      true
    );
    perform set_config(
      'request.jwt.claim.sub',
      'a1000000-0000-4000-8000-000000000001',
      true
    );

    insert into public.orders (
      order_number, user_id, subtotal, discount_total, shipping_fee, grand_total,
      recipient_name, recipient_phone, shipping_address
    ) values (
      'BDM-TEST-DIRECT',
      'a1000000-0000-4000-8000-000000000001',
      100, 0, 0, 100,
      'Buyer One', '0901000001', '{}'::jsonb
    );
  exception
    when insufficient_privilege then
      v_ok := true;
    when others then
      -- RLS typically raises insufficient_privilege; accept that class only.
      if sqlstate = '42501' then
        v_ok := true;
      else
        raise exception
          'FAIL: direct order INSERT raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  reset role;
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);

  if not v_ok then
    raise exception 'FAIL: authenticated customer direct INSERT on orders succeeded';
  end if;

  v_ok := false;
  begin
    set local role authenticated;
    perform set_config(
      'request.jwt.claims',
      json_build_object(
        'sub', 'a1000000-0000-4000-8000-000000000001',
        'role', 'authenticated'
      )::text,
      true
    );
    perform set_config(
      'request.jwt.claim.sub',
      'a1000000-0000-4000-8000-000000000001',
      true
    );

    update public.inventory
    set quantity_reserved = quantity_reserved + 1
    where variant_id = '40000000-0000-4000-8000-000000000001';

    if found then
      raise exception 'FAIL: authenticated customer UPDATE on inventory succeeded';
    end if;
    -- Zero-row update under RLS still "succeeds" SQL-wise; require privilege error
    -- or zero rows with no mutation. Prefer privilege denial when present.
    v_ok := true;
  exception
    when insufficient_privilege then
      v_ok := true;
    when others then
      if sqlstate = '42501' then
        v_ok := true;
      else
        raise exception
          'FAIL: inventory UPDATE raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  reset role;
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);

  if not v_ok then
    raise exception 'FAIL: authenticated inventory write path not blocked';
  end if;

  -- Confirm reserved quantity unchanged after the customer UPDATE attempt.
  if (
    select quantity_reserved
    from public.inventory
    where variant_id = '40000000-0000-4000-8000-000000000001'
  ) is distinct from 2 then
    raise exception 'FAIL: customer inventory UPDATE mutated reserved quantity';
  end if;

  raise notice 'OK: customer direct order/inventory writes remain blocked';
end $$;

-- Function search_path must be empty / fixed.
do $$
declare
  v_config text[];
  v_cfg text;
  v_ok boolean := false;
begin
  select p.proconfig
  into v_config
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'checkout_cod'
    and pg_get_function_identity_arguments(p.oid) =
      'p_shipping_address_id uuid, p_customer_note text';

  if v_config is not null then
    foreach v_cfg in array v_config loop
      if v_cfg in ('search_path=', 'search_path=""') then
        v_ok := true;
      end if;
    end loop;
  end if;

  if not v_ok then
    raise exception 'FAIL: checkout_cod search_path is not empty (proconfig=%)',
      v_config;
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'checkout_cod'
      and p.prosecdef = true
  ) then
    raise exception 'FAIL: checkout_cod is not SECURITY DEFINER';
  end if;

  raise notice 'OK: checkout_cod is SECURITY DEFINER with empty search_path';
end $$;

-- ---------------------------------------------------------------------------
-- Auth helpers / fixtures (rolled back)
-- ---------------------------------------------------------------------------
create temporary table checkout_test_users (
  label text primary key,
  user_id uuid not null
) on commit drop;

create or replace function pg_temp.checkout_test_insert_user(
  p_label text,
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
    crypt('checkout-test-password', gen_salt('bf')),
    timezone('utc', now()),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    timezone('utc', now()),
    timezone('utc', now())
  );

  insert into checkout_test_users (label, user_id)
  values (p_label, p_user_id);
end;
$$;

create or replace function pg_temp.checkout_test_set_auth(p_user_id uuid)
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

create or replace function pg_temp.checkout_test_clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

select pg_temp.checkout_test_insert_user(
  'buyer',
  'a1000000-0000-4000-8000-000000000001',
  'checkout-buyer@example.invalid'
);
select pg_temp.checkout_test_insert_user(
  'other',
  'a1000000-0000-4000-8000-000000000002',
  'checkout-other@example.invalid'
);
select pg_temp.checkout_test_insert_user(
  'inactive',
  'a1000000-0000-4000-8000-000000000003',
  'checkout-inactive@example.invalid'
);

update public.profiles
set is_active = false
where id = 'a1000000-0000-4000-8000-000000000003';

insert into public.addresses (
  id,
  user_id,
  recipient_name,
  phone_number,
  province_name,
  district_name,
  ward_name,
  street_address,
  is_default
) values
  (
    'a2000000-0000-4000-8000-000000000001',
    'a1000000-0000-4000-8000-000000000001',
    'Buyer One',
    '0901000001',
    'TP Hồ Chí Minh',
    'Quận 1',
    'Phường Bến Nghé',
    '1 Nguyễn Huệ',
    true
  ),
  (
    'a2000000-0000-4000-8000-000000000002',
    'a1000000-0000-4000-8000-000000000002',
    'Other User',
    '0901000002',
    'Hà Nội',
    'Quận Ba Đình',
    'Phường Điện Biên',
    '2 Hoàng Diệu',
    true
  ),
  (
    'a2000000-0000-4000-8000-000000000003',
    'a1000000-0000-4000-8000-000000000003',
    'Inactive User',
    '0901000003',
    'Đà Nẵng',
    'Quận Hải Châu',
    'Phường Thạch Thang',
    '3 Bạch Đằng',
    true
  );

-- ---------------------------------------------------------------------------
-- Unauthenticated / role auth failures
-- ---------------------------------------------------------------------------
do $$
declare
  v_order_id uuid;
begin
  perform pg_temp.checkout_test_clear_auth();

  begin
    set local role anon;
    select public.checkout_cod(
      'a2000000-0000-4000-8000-000000000001',
      null
    ) into v_order_id;
    raise exception 'FAIL: anon EXECUTE unexpectedly succeeded';
  exception
    when insufficient_privilege then
      null; -- expected (no EXECUTE)
    when others then
      if sqlerrm like '%permission denied%' or sqlstate = '42501' then
        null;
      else
        raise exception
          'FAIL: anon call raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  reset role;
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);

  begin
    set local role authenticated;
    select public.checkout_cod(
      'a2000000-0000-4000-8000-000000000001',
      null
    ) into v_order_id;
    raise exception 'FAIL: authenticated without subject unexpectedly succeeded';
  exception
    when insufficient_privilege then
      null;
    when others then
      if sqlerrm like '%authenticated user%' or sqlstate = '42501' then
        null;
      else
        raise exception
          'FAIL: null-subject call raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  reset role;

  begin
    set local role service_role;
    perform set_config('request.jwt.claim.sub', '', true);
    perform set_config('request.jwt.claims', '', true);
    select public.checkout_cod(
      'a2000000-0000-4000-8000-000000000001',
      null
    ) into v_order_id;
    raise exception 'FAIL: service_role without auth.uid() unexpectedly succeeded';
  exception
    when others then
      if sqlerrm like '%authenticated user%' or sqlstate = '42501' then
        null;
      else
        raise exception
          'FAIL: service_role null-uid raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  reset role;
  perform pg_temp.checkout_test_clear_auth();
  raise notice 'OK: anon / null-subject / service_role-without-uid rejected';
end $$;

-- ---------------------------------------------------------------------------
-- Ownership / inactive profile
-- ---------------------------------------------------------------------------
do $$
declare
  v_order_id uuid;
  v_orders_before integer;
  v_orders_after integer;
begin
  select count(*)::integer into v_orders_before from public.orders;

  perform pg_temp.checkout_test_set_auth(
    'a1000000-0000-4000-8000-000000000001'
  );

  insert into public.carts (id, user_id, status, currency_code)
  values (
    'a3000000-0000-4000-8000-0000000000aa',
    'a1000000-0000-4000-8000-000000000001',
    'active',
    'VND'
  );
  insert into public.cart_items (cart_id, variant_id, quantity, unit_price_snapshot)
  values (
    'a3000000-0000-4000-8000-0000000000aa',
    '40000000-0000-4000-8000-000000000001',
    1,
    1.00
  );

  begin
    select public.checkout_cod(
      'a2000000-0000-4000-8000-000000000002', -- other user's address
      'should fail'
    ) into v_order_id;
    raise exception 'FAIL: cross-user address checkout unexpectedly succeeded';
  exception
    when others then
      if sqlerrm like '%shipping address not found%' then
        null;
      else
        raise exception
          'FAIL: cross-user address raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  select count(*)::integer into v_orders_after from public.orders;
  if v_orders_after <> v_orders_before then
    raise exception 'FAIL: cross-user address failure leaked an order';
  end if;

  perform pg_temp.checkout_test_set_auth(
    'a1000000-0000-4000-8000-000000000003'
  );

  begin
    select public.checkout_cod(
      'a2000000-0000-4000-8000-000000000003',
      null
    ) into v_order_id;
    raise exception 'FAIL: inactive profile checkout unexpectedly succeeded';
  exception
    when others then
      if sqlerrm like '%active profile%' or sqlstate = '42501' then
        null;
      else
        raise exception
          'FAIL: inactive profile raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  -- Clean buyer cart for later scenarios (still same outer transaction).
  perform pg_temp.checkout_test_clear_auth();
  delete from public.cart_items
  where cart_id = 'a3000000-0000-4000-8000-0000000000aa';
  delete from public.carts
  where id = 'a3000000-0000-4000-8000-0000000000aa';

  raise notice 'OK: cross-user address and inactive profile rejected';
end $$;

-- ---------------------------------------------------------------------------
-- Validation failures leave no partial side effects
-- ---------------------------------------------------------------------------
do $$
declare
  v_buyer uuid := 'a1000000-0000-4000-8000-000000000001';
  v_address uuid := 'a2000000-0000-4000-8000-000000000001';
  v_cart uuid := 'a3000000-0000-4000-8000-0000000000bb';
  v_order_id uuid;
  v_orders_before integer;
  v_items_before integer;
  v_history_before integer;
  v_reserved_before integer;
  v_cart_status text;
  v_variant uuid;
  v_qty integer;
begin
  select count(*)::integer into v_orders_before from public.orders;
  select count(*)::integer into v_items_before from public.order_items;
  select count(*)::integer into v_history_before from public.order_status_history;

  -- No active cart
  perform pg_temp.checkout_test_set_auth(v_buyer);
  begin
    select public.checkout_cod(v_address, null) into v_order_id;
    raise exception 'FAIL: missing active cart unexpectedly succeeded';
  exception
    when others then
      if sqlerrm like '%active cart%' then
        null;
      else
        raise exception
          'FAIL: missing cart raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  -- Empty cart
  perform pg_temp.checkout_test_clear_auth();
  insert into public.carts (id, user_id, status, currency_code)
  values (v_cart, v_buyer, 'active', 'VND');

  perform pg_temp.checkout_test_set_auth(v_buyer);
  begin
    select public.checkout_cod(v_address, null) into v_order_id;
    raise exception 'FAIL: empty cart checkout unexpectedly succeeded';
  exception
    when others then
      if sqlerrm like '%cart is empty%' then
        null;
      else
        raise exception
          'FAIL: empty cart raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  -- Inactive variant
  perform pg_temp.checkout_test_clear_auth();
  insert into public.cart_items (cart_id, variant_id, quantity)
  values (v_cart, '40000000-0000-4000-8000-000000000028', 1);

  perform pg_temp.checkout_test_set_auth(v_buyer);
  begin
    select public.checkout_cod(v_address, null) into v_order_id;
    raise exception 'FAIL: inactive variant checkout unexpectedly succeeded';
  exception
    when others then
      if sqlerrm like '%invalid catalog%' then
        null;
      else
        raise exception
          'FAIL: inactive variant raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  -- Draft / non-active product
  perform pg_temp.checkout_test_clear_auth();
  delete from public.cart_items where cart_id = v_cart;
  insert into public.cart_items (cart_id, variant_id, quantity)
  values (v_cart, '40000000-0000-4000-8000-000000000017', 1);

  perform pg_temp.checkout_test_set_auth(v_buyer);
  begin
    select public.checkout_cod(v_address, null) into v_order_id;
    raise exception 'FAIL: draft product checkout unexpectedly succeeded';
  exception
    when others then
      if sqlerrm like '%invalid catalog%' then
        null;
      else
        raise exception
          'FAIL: draft product raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  -- Missing inventory row
  perform pg_temp.checkout_test_clear_auth();
  delete from public.cart_items where cart_id = v_cart;
  v_variant := '40000000-0000-4000-8000-000000000002';
  delete from public.inventory where variant_id = v_variant;
  insert into public.cart_items (cart_id, variant_id, quantity)
  values (v_cart, v_variant, 1);

  perform pg_temp.checkout_test_set_auth(v_buyer);
  begin
    select public.checkout_cod(v_address, null) into v_order_id;
    raise exception 'FAIL: missing inventory checkout unexpectedly succeeded';
  exception
    when others then
      if sqlerrm like '%invalid catalog%' then
        null;
      else
        raise exception
          'FAIL: missing inventory raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  -- Restore inventory for the deleted seed row (transaction will roll back anyway).
  perform pg_temp.checkout_test_clear_auth();
  insert into public.inventory (
    variant_id, quantity_on_hand, quantity_reserved, reorder_level, allow_backorder
  ) values (v_variant, 7, 0, 5, false);

  -- Insufficient stock (no backorder)
  delete from public.cart_items where cart_id = v_cart;
  v_variant := '40000000-0000-4000-8000-000000000004'; -- on_hand=0, reserved=0
  select quantity_reserved into v_reserved_before
  from public.inventory where variant_id = v_variant;

  insert into public.cart_items (cart_id, variant_id, quantity)
  values (v_cart, v_variant, 1);

  perform pg_temp.checkout_test_set_auth(v_buyer);
  begin
    select public.checkout_cod(v_address, null) into v_order_id;
    raise exception 'FAIL: insufficient stock checkout unexpectedly succeeded';
  exception
    when others then
      if sqlerrm like '%insufficient stock%' then
        null;
      else
        raise exception
          'FAIL: insufficient stock raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  if (
    select quantity_reserved from public.inventory where variant_id = v_variant
  ) <> v_reserved_before then
    raise exception 'FAIL: insufficient stock mutated quantity_reserved';
  end if;

  -- Multi-line rollback: one valid line + one understocked line
  perform pg_temp.checkout_test_clear_auth();
  delete from public.cart_items where cart_id = v_cart;
  insert into public.cart_items (cart_id, variant_id, quantity, unit_price_snapshot)
  values
    (v_cart, '40000000-0000-4000-8000-000000000001', 1, 999.00),
    (v_cart, '40000000-0000-4000-8000-000000000004', 1, 999.00);

  select quantity_reserved into v_reserved_before
  from public.inventory
  where variant_id = '40000000-0000-4000-8000-000000000001';

  perform pg_temp.checkout_test_set_auth(v_buyer);
  begin
    select public.checkout_cod(v_address, 'partial must not commit')
      into v_order_id;
    raise exception 'FAIL: multi-line understock unexpectedly succeeded';
  exception
    when others then
      if sqlerrm like '%insufficient stock%' then
        null;
      else
        raise exception
          'FAIL: multi-line understock raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  if (
    select count(*)::integer from public.orders
  ) <> v_orders_before
     or (
       select count(*)::integer from public.order_items
     ) <> v_items_before
     or (
       select count(*)::integer from public.order_status_history
     ) <> v_history_before
  then
    raise exception 'FAIL: validation failure left order/history rows';
  end if;

  if (
    select quantity_reserved
    from public.inventory
    where variant_id = '40000000-0000-4000-8000-000000000001'
  ) <> v_reserved_before then
    raise exception 'FAIL: multi-line failure partially reserved stock';
  end if;

  select status into v_cart_status from public.carts where id = v_cart;
  if v_cart_status is distinct from 'active' then
    raise exception 'FAIL: validation failure converted cart';
  end if;

  perform pg_temp.checkout_test_clear_auth();
  delete from public.cart_items where cart_id = v_cart;
  delete from public.carts where id = v_cart;

  raise notice 'OK: validation failures leave no partial checkout side effects';
end $$;

-- ---------------------------------------------------------------------------
-- Successful COD path + backorder + idempotent retry
-- ---------------------------------------------------------------------------
do $$
declare
  v_buyer uuid := 'a1000000-0000-4000-8000-000000000001';
  v_address uuid := 'a2000000-0000-4000-8000-000000000001';
  v_cart uuid := 'a3000000-0000-4000-8000-0000000000cc';
  v_variant_a uuid := '40000000-0000-4000-8000-000000000001';
  v_variant_b uuid := '40000000-0000-4000-8000-000000000042';
  v_backorder_variant uuid := '40000000-0000-4000-8000-000000000050';
  v_order_id uuid;
  v_retry_id uuid;
  v_order public.orders%rowtype;
  v_item public.order_items%rowtype;
  v_price_a numeric(14, 2);
  v_price_b numeric(14, 2);
  v_reserved_a_before integer;
  v_reserved_b_before integer;
  v_reserved_back_before integer;
  v_history_count integer;
  v_snapshot_keys text[];
  v_buyer_order_count integer;
  v_notif_count integer;
  v_notif_payload jsonb;
  v_notif_user uuid;
begin
  select price into v_price_a
  from public.product_variants where id = v_variant_a;
  select price into v_price_b
  from public.product_variants where id = v_variant_b;

  select quantity_reserved into v_reserved_a_before
  from public.inventory where variant_id = v_variant_a;
  select quantity_reserved into v_reserved_b_before
  from public.inventory where variant_id = v_variant_b;

  insert into public.carts (id, user_id, status, currency_code)
  values (v_cart, v_buyer, 'active', 'VND');

  insert into public.cart_items (
    cart_id, variant_id, quantity, unit_price_snapshot
  ) values
    (v_cart, v_variant_a, 2, 1.00), -- stale snapshot must be ignored
    (v_cart, v_variant_b, 3, 2.00);

  perform pg_temp.checkout_test_set_auth(v_buyer);
  select public.checkout_cod(v_address, '  please call on arrival  ')
    into v_order_id;

  if v_order_id is null then
    raise exception 'FAIL: successful checkout returned null order id';
  end if;

  select * into v_order from public.orders where id = v_order_id;
  if v_order.user_id is distinct from v_buyer
     or v_order.status is distinct from 'pending'
     or v_order.payment_method is distinct from 'cod'
     or v_order.payment_status is distinct from 'unpaid'
     or v_order.currency_code is distinct from 'VND'
     or v_order.discount_total is distinct from 0
     or v_order.shipping_fee is distinct from 0
     or v_order.subtotal is distinct from (v_price_a * 2 + v_price_b * 3)
     or v_order.grand_total is distinct from v_order.subtotal
     or v_order.customer_note is distinct from 'please call on arrival'
     or v_order.recipient_name is distinct from 'Buyer One'
     or v_order.recipient_phone is distinct from '0901000001'
     or (v_order.shipping_address ->> 'street_address')
          is distinct from '1 Nguyễn Huệ'
  then
    raise exception 'FAIL: order row fields incorrect for successful COD checkout';
  end if;

  if (
    select count(*)::integer from public.order_items where order_id = v_order_id
  ) <> 2 then
    raise exception 'FAIL: expected exactly two order_items';
  end if;

  select * into v_item
  from public.order_items
  where order_id = v_order_id and variant_id = v_variant_a;

  if v_item.unit_price is distinct from v_price_a
     or v_item.quantity is distinct from 2
     or v_item.line_total is distinct from (v_price_a * 2)
     or v_item.sku is distinct from 'RKT-YON-AS88-RED-3U-G5'
     or v_item.product_name is null
     or v_item.variant_name is null
     or v_item.image_path is null
  then
    raise exception 'FAIL: order item A snapshot incorrect';
  end if;

  select array_agg(key order by key)
  into v_snapshot_keys
  from jsonb_object_keys(v_item.product_snapshot) as key;

  if v_item.product_snapshot ? 'cost_price'
     or not (v_item.product_snapshot ? 'product_id')
     or not (v_item.product_snapshot ? 'variant_id')
     or not (v_item.product_snapshot ? 'sku')
     or not (v_item.product_snapshot ? 'product_name')
  then
    raise exception
      'FAIL: product_snapshot keys unsafe or incomplete: %',
      v_snapshot_keys;
  end if;

  select count(*)::integer into v_history_count
  from public.order_status_history
  where order_id = v_order_id;

  if v_history_count <> 1 then
    raise exception
      'FAIL: expected exactly one status-history row from insert trigger (got %)',
      v_history_count;
  end if;

  if (
    select quantity_reserved from public.inventory where variant_id = v_variant_a
  ) <> v_reserved_a_before + 2 then
    raise exception 'FAIL: inventory reservation for variant A incorrect';
  end if;

  if (
    select quantity_reserved from public.inventory where variant_id = v_variant_b
  ) <> v_reserved_b_before + 3 then
    raise exception 'FAIL: inventory reservation for variant B incorrect';
  end if;

  if (
    select status from public.carts where id = v_cart
  ) is distinct from 'converted' then
    raise exception 'FAIL: cart was not converted';
  end if;

  select count(*)::integer into v_notif_count
  from public.notifications
  where user_id = v_buyer
    and type = 'order_update';

  if v_notif_count <> 1 then
    raise exception
      'FAIL: successful checkout expected one order_update notification (got %)',
      v_notif_count;
  end if;

  select payload, user_id
  into v_notif_payload, v_notif_user
  from public.notifications
  where user_id = v_buyer
    and type = 'order_update'
    and payload ->> 'order_id' = v_order_id::text;

  if v_notif_user is distinct from v_buyer
     or v_notif_payload ->> 'order_number' is null
     or pg_catalog.btrim(v_notif_payload ->> 'order_number') = ''
     or v_notif_payload ->> 'order_number'
          is distinct from v_order.order_number
     or v_notif_payload ->> 'event' is distinct from 'order_placed'
     or v_notif_payload ->> 'status' is distinct from 'pending'
     or v_notif_payload ? 'from_status'
     or v_notif_payload ? 'to_status'
     or v_notif_payload ? 'phone_number'
     or v_notif_payload ? 'email'
     or v_notif_payload ? 'note'
  then
    raise exception 'FAIL: checkout order_update notification payload contract';
  end if;

  -- Idempotent retry after conversion must not create a second order.
  select count(*)::integer into v_buyer_order_count
  from public.orders where user_id = v_buyer;

  begin
    select public.checkout_cod(v_address, 'retry') into v_retry_id;
    raise exception 'FAIL: retry after conversion unexpectedly succeeded';
  exception
    when others then
      if sqlerrm like '%active cart%' then
        null;
      else
        raise exception
          'FAIL: retry after conversion raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  if (
    select count(*)::integer from public.orders where user_id = v_buyer
  ) <> v_buyer_order_count then
    raise exception 'FAIL: retry after conversion created a duplicate order';
  end if;

  select count(*)::integer into v_notif_count
  from public.notifications
  where user_id = v_buyer
    and type = 'order_update';

  if v_notif_count <> 1 then
    raise exception
      'FAIL: checkout retry created duplicate notifications (count=%)',
      v_notif_count;
  end if;

  -- Explicit backorder path
  perform pg_temp.checkout_test_clear_auth();
  insert into public.carts (id, user_id, status, currency_code)
  values (
    'a3000000-0000-4000-8000-0000000000dd',
    v_buyer,
    'active',
    'VND'
  );
  insert into public.cart_items (cart_id, variant_id, quantity)
  values (
    'a3000000-0000-4000-8000-0000000000dd',
    v_backorder_variant,
    2
  );

  select quantity_reserved into v_reserved_back_before
  from public.inventory where variant_id = v_backorder_variant;

  if not (
    select allow_backorder
    from public.inventory
    where variant_id = v_backorder_variant
  ) then
    raise exception 'FAIL: expected seeded backorder variant';
  end if;

  perform pg_temp.checkout_test_set_auth(v_buyer);
  select public.checkout_cod(v_address, null) into v_order_id;

  if (
    select quantity_reserved
    from public.inventory
    where variant_id = v_backorder_variant
  ) <> v_reserved_back_before + 2 then
    raise exception 'FAIL: backorder reservation did not increase by quantity';
  end if;

  if (
    select quantity_reserved
    from public.inventory
    where variant_id = v_backorder_variant
  ) < 0 then
    raise exception 'FAIL: backorder reservation became negative';
  end if;

  perform pg_temp.checkout_test_clear_auth();
  raise notice 'OK: successful COD, snapshots, reservation, retry, backorder';
end $$;

-- Direct mutation against a converted cart must fail (active-cart trigger).
-- Two-session phantom coverage lives in
-- 03_trusted_cod_checkout_concurrency.sh (requires parallel psql sessions).
do $$
declare
  v_buyer uuid := 'a1000000-0000-4000-8000-000000000001';
  v_cart uuid := 'a3000000-0000-4000-8000-0000000000ee';
  v_ok boolean := false;
begin
  insert into public.carts (id, user_id, status, currency_code)
  values (v_cart, v_buyer, 'converted', 'VND');

  perform pg_temp.checkout_test_set_auth(v_buyer);
  begin
    insert into public.cart_items (cart_id, variant_id, quantity)
    values (v_cart, '40000000-0000-4000-8000-000000000001', 1);
  exception
    when others then
      if sqlerrm like '%active cart%' then
        v_ok := true;
      else
        raise exception
          'FAIL: converted-cart INSERT raised unexpected SQLSTATE %: %',
          sqlstate,
          sqlerrm;
      end if;
  end;

  perform pg_temp.checkout_test_clear_auth();

  if not v_ok then
    raise exception 'FAIL: INSERT into converted cart unexpectedly succeeded';
  end if;

  if exists (select 1 from public.cart_items where cart_id = v_cart) then
    raise exception 'FAIL: converted cart retained a rejected insert row';
  end if;

  delete from public.carts where id = v_cart;
  raise notice 'OK: converted-cart cart_items INSERT rejected by active-cart trigger';
end $$;

-- Failed checkout must not emit notifications (atomic side-effect pairing).
do $$
declare
  v_buyer uuid := 'a1000000-0000-4000-8000-000000000001';
  v_address uuid := 'a2000000-0000-4000-8000-000000000001';
  v_cart uuid := 'a3000000-0000-4000-8000-0000000000ff';
  v_before integer;
  v_after integer;
begin
  select count(*)::integer into v_before
  from public.notifications
  where user_id = v_buyer;

  insert into public.carts (id, user_id, status, currency_code)
  values (v_cart, v_buyer, 'active', 'VND');

  perform pg_temp.checkout_test_set_auth(v_buyer);
  begin
    perform public.checkout_cod(v_address, null);
    raise exception 'FAIL: empty-cart checkout unexpectedly succeeded';
  exception
    when others then
      if sqlerrm not like '%empty%' then
        raise exception
          'FAIL: empty-cart checkout raised unexpected error: %',
          sqlerrm;
      end if;
  end;
  perform pg_temp.checkout_test_clear_auth();

  select count(*)::integer into v_after
  from public.notifications
  where user_id = v_buyer;

  if v_after <> v_before then
    raise exception
      'FAIL: failed checkout changed notification count (% -> %)',
      v_before,
      v_after;
  end if;

  delete from public.carts where id = v_cart;
  raise notice 'OK: failed checkout emits no notification';
end $$;

-- Notification insert failure must roll back the checkout transaction.
do $checkout_atomicity$
declare
  v_buyer uuid := 'a1000000-0000-4000-8000-000000000001';
  v_address uuid := 'a2000000-0000-4000-8000-000000000001';
  v_cart uuid := 'a3000000-0000-4000-8000-0000000000aa';
  v_variant uuid := '40000000-0000-4000-8000-000000000001';
  v_orders_before integer;
  v_orders_after integer;
  v_notif_before integer;
  v_notif_after integer;
begin
  create or replace function pg_temp.checkout_block_notifications()
  returns trigger
  language plpgsql
  as $block_fn$
  begin
    if current_setting('pg_temp.checkout_block_notifications', true) = 'on' then
      raise exception 'simulated notification insert failure';
    end if;
    return new;
  end;
  $block_fn$;

  drop trigger if exists checkout_block_notifications on public.notifications;
  create trigger checkout_block_notifications
  before insert on public.notifications
  for each row
  execute function pg_temp.checkout_block_notifications();

  insert into public.carts (id, user_id, status, currency_code)
  values (v_cart, v_buyer, 'active', 'VND');

  insert into public.cart_items (cart_id, variant_id, quantity)
  values (v_cart, v_variant, 1);

  select count(*)::integer into v_orders_before
  from public.orders
  where user_id = v_buyer;

  select count(*)::integer into v_notif_before
  from public.notifications
  where user_id = v_buyer;

  perform set_config('pg_temp.checkout_block_notifications', 'on', true);
  perform pg_temp.checkout_test_set_auth(v_buyer);
  begin
    perform public.checkout_cod(v_address, null);
    perform pg_temp.checkout_test_clear_auth();
    raise exception 'FAIL: checkout succeeded when notifications blocked';
  exception
    when others then
      perform pg_temp.checkout_test_clear_auth();
      if sqlerrm not like '%simulated notification insert failure%' then
        raise exception
          'FAIL: blocked-notification checkout raised unexpected error: %',
          sqlerrm;
      end if;
  end;
  perform set_config('pg_temp.checkout_block_notifications', 'off', true);

  select count(*)::integer into v_orders_after
  from public.orders
  where user_id = v_buyer;

  select count(*)::integer into v_notif_after
  from public.notifications
  where user_id = v_buyer;

  if v_orders_after <> v_orders_before or v_notif_after <> v_notif_before then
    raise exception
      'FAIL: notification failure did not roll back checkout side effects';
  end if;

  if (
    select status from public.carts where id = v_cart
  ) is distinct from 'active' then
    raise exception 'FAIL: notification failure left cart converted';
  end if;

  drop trigger if exists checkout_block_notifications on public.notifications;
  delete from public.cart_items where cart_id = v_cart;
  delete from public.carts where id = v_cart;

  raise notice 'OK: notification insert failure rolls back checkout';
end;
$checkout_atomicity$;

-- Deterministic lock ordering is encoded in the RPC (cart lines by
-- variant_id/id, inventory by variant_id). Concurrent retries serialize on the
-- active cart row FOR UPDATE; a second caller after conversion hits
-- "requires an active cart" without creating a duplicate order (covered above).
-- Concurrent cart_items INSERT vs checkout is covered by
-- 03_trusted_cod_checkout_concurrency.sh (active-cart trigger + cart FOR UPDATE).

rollback;

\echo '== done =='
