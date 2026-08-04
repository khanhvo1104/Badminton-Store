-- Executable regression: explicit least-privilege Data API grants (TASK-008).
--
-- Separates grant-layer assertions (has_*_privilege / information_schema)
-- from representative role-switched RLS behavior.
--
-- Run against an already migrated + seeded disposable local database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/05_explicit_data_api_grants.sql
--
-- Fixtures run inside a transaction and roll back. Do not print tokens,
-- secrets, cost_price values, order payloads, or full JWT claims.

\echo '== explicit Data API grants regression =='

begin;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function pg_temp.grants_insert_user(
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
    crypt('grants-test-password', gen_salt('bf')),
    timezone('utc', now()),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    timezone('utc', now()),
    timezone('utc', now())
  );
end;
$$;

create or replace function pg_temp.grants_set_auth(p_user_id uuid)
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

-- Forged JWT app_metadata / user_metadata role must not create staff authority.
create or replace function pg_temp.grants_set_auth_forged_staff(p_user_id uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', p_user_id::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', p_user_id::text,
      'role', 'authenticated',
      'app_metadata', json_build_object('role', 'admin'),
      'user_metadata', json_build_object('role', 'staff')
    )::text,
    true
  );
  execute 'set local role authenticated';
end;
$$;

create or replace function pg_temp.grants_clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

create or replace function pg_temp.assert_denied_or_zero(
  p_label text,
  p_sql text,
  p_expect_mutation boolean default false
)
returns void
language plpgsql
as $$
declare
  v_denied boolean := false;
  v_n integer;
begin
  begin
    execute p_sql;
    if p_expect_mutation then
      get diagnostics v_n = row_count;
      if v_n = 0 then
        v_denied := true;
      end if;
    else
      -- SELECT path: caller checks counts separately when needed.
      null;
    end if;
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate = '42501' then
        v_denied := true;
      else
        perform pg_temp.grants_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %: %',
          p_label,
          sqlstate,
          sqlerrm;
      end if;
  end;

  if p_expect_mutation and not v_denied then
    perform pg_temp.grants_clear_auth();
    raise exception 'FAIL: % unexpectedly mutated rows', p_label;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Grant-layer: anon matrix (independent of RLS outcomes)
-- ---------------------------------------------------------------------------
do $$
declare
  catalog_tables text[] := array[
    'categories', 'brands', 'products', 'product_images', 'product_catalog'
  ];
  denied_tables text[] := array[
    'profiles', 'addresses', 'favorites', 'carts', 'cart_items',
    'orders', 'order_items', 'order_status_history', 'inventory',
    'inventory_availability'
  ];
  t text;
  write_priv text;
  table_select_grantee text;
  safe_cols text[] := array[
    'id', 'product_id', 'sku', 'name', 'color_name', 'color_hex',
    'racket_weight_class', 'grip_size', 'shoe_size', 'clothing_size',
    'unit', 'price', 'compare_at_price', 'attributes', 'is_default',
    'is_active', 'sort_order'
  ];
  col text;
begin
  foreach t in array catalog_tables loop
    if not has_table_privilege('anon', format('public.%I', t), 'SELECT') then
      raise exception 'FAIL: anon missing SELECT on public.%', t;
    end if;
    foreach write_priv in array array['INSERT', 'UPDATE', 'DELETE'] loop
      if has_table_privilege('anon', format('public.%I', t), write_priv) then
        raise exception 'FAIL: anon has % on public.%', write_priv, t;
      end if;
    end loop;
  end loop;

  foreach t in array denied_tables loop
    if has_table_privilege('anon', format('public.%I', t), 'SELECT') then
      raise exception 'FAIL: anon has SELECT on public.%', t;
    end if;
    foreach write_priv in array array['INSERT', 'UPDATE', 'DELETE'] loop
      if has_table_privilege('anon', format('public.%I', t), write_priv) then
        raise exception 'FAIL: anon has % on public.%', write_priv, t;
      end if;
    end loop;
  end loop;

  -- product_variants: no table-wide SELECT; safe columns only; no cost_price.
  for table_select_grantee in
    select grantee
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'product_variants'
      and privilege_type = 'SELECT'
      and grantee in ('anon', 'authenticated')
  loop
    raise exception
      'FAIL: % still has table-wide SELECT on product_variants',
      table_select_grantee;
  end loop;

  if has_column_privilege(
    'anon', 'public.product_variants', 'cost_price', 'SELECT'
  ) then
    raise exception 'FAIL: anon can SELECT product_variants.cost_price';
  end if;

  foreach col in array safe_cols loop
    if not has_column_privilege(
      'anon', 'public.product_variants', col, 'SELECT'
    ) then
      raise exception 'FAIL: anon missing SELECT on product_variants.%', col;
    end if;
  end loop;

  if not has_function_privilege(
    'anon', 'public.get_variant_availability(uuid)', 'EXECUTE'
  ) then
    raise exception 'FAIL: anon missing EXECUTE on get_variant_availability';
  end if;
  if not has_function_privilege(
    'anon', 'public.search_products(text, integer)', 'EXECUTE'
  ) then
    raise exception 'FAIL: anon missing EXECUTE on search_products';
  end if;
  if has_function_privilege(
    'anon', 'public.checkout_cod(uuid, text)', 'EXECUTE'
  ) then
    raise exception 'FAIL: anon has EXECUTE on checkout_cod';
  end if;

  raise notice 'OK: anon grant-layer matrix';
end $$;

-- ---------------------------------------------------------------------------
-- Grant-layer: authenticated customer + staff operation surface
-- ---------------------------------------------------------------------------
do $$
begin
  if not has_table_privilege('authenticated', 'public.profiles', 'SELECT') then
    raise exception 'FAIL: authenticated missing SELECT on profiles';
  end if;
  if not has_table_privilege('authenticated', 'public.profiles', 'UPDATE') then
    raise exception 'FAIL: authenticated missing UPDATE on profiles';
  end if;

  if not (
    has_table_privilege('authenticated', 'public.addresses', 'SELECT')
    and has_table_privilege('authenticated', 'public.addresses', 'INSERT')
    and has_table_privilege('authenticated', 'public.addresses', 'UPDATE')
    and has_table_privilege('authenticated', 'public.addresses', 'DELETE')
  ) then
    raise exception 'FAIL: authenticated missing addresses CRUD grants';
  end if;

  if not (
    has_table_privilege('authenticated', 'public.favorites', 'SELECT')
    and has_table_privilege('authenticated', 'public.favorites', 'INSERT')
    and has_table_privilege('authenticated', 'public.favorites', 'DELETE')
  ) then
    raise exception 'FAIL: authenticated missing favorites SID grants';
  end if;

  if not (
    has_table_privilege('authenticated', 'public.carts', 'SELECT')
    and has_table_privilege('authenticated', 'public.carts', 'INSERT')
    and has_table_privilege('authenticated', 'public.carts', 'UPDATE')
    and has_table_privilege('authenticated', 'public.carts', 'DELETE')
  ) then
    raise exception 'FAIL: authenticated missing carts CRUD grants';
  end if;

  if not (
    has_table_privilege('authenticated', 'public.cart_items', 'SELECT')
    and has_table_privilege('authenticated', 'public.cart_items', 'INSERT')
    and has_table_privilege('authenticated', 'public.cart_items', 'UPDATE')
    and has_table_privilege('authenticated', 'public.cart_items', 'DELETE')
  ) then
    raise exception 'FAIL: authenticated missing cart_items CRUD grants';
  end if;

  if not has_table_privilege('authenticated', 'public.orders', 'SELECT') then
    raise exception 'FAIL: authenticated missing SELECT on orders';
  end if;
  if not has_table_privilege('authenticated', 'public.order_items', 'SELECT') then
    raise exception 'FAIL: authenticated missing SELECT on order_items';
  end if;
  if not has_table_privilege(
    'authenticated', 'public.order_status_history', 'SELECT'
  ) then
    raise exception 'FAIL: authenticated missing SELECT on order_status_history';
  end if;

  -- Staff-required operation grants (RLS still gates customers).
  if not (
    has_table_privilege('authenticated', 'public.categories', 'INSERT')
    and has_table_privilege('authenticated', 'public.inventory', 'SELECT')
    and has_table_privilege('authenticated', 'public.inventory', 'UPDATE')
    and has_table_privilege('authenticated', 'public.orders', 'INSERT')
    and has_table_privilege('authenticated', 'public.orders', 'UPDATE')
    and has_table_privilege('authenticated', 'public.order_items', 'INSERT')
    and has_table_privilege(
      'authenticated', 'public.order_status_history', 'INSERT'
    )
  ) then
    raise exception 'FAIL: authenticated missing staff operation grants';
  end if;

  if has_column_privilege(
    'authenticated', 'public.product_variants', 'cost_price', 'SELECT'
  ) then
    raise exception
      'FAIL: authenticated can SELECT product_variants.cost_price';
  end if;

  if not has_column_privilege(
    'service_role', 'public.product_variants', 'cost_price', 'SELECT'
  ) then
    raise exception
      'FAIL: service_role lost SELECT on product_variants.cost_price';
  end if;

  raise notice 'OK: authenticated/service_role grant-layer matrix';
end $$;

-- ---------------------------------------------------------------------------
-- Grant-layer: function contracts
-- ---------------------------------------------------------------------------
do $$
declare
  protected text[] := array[
    'public.prevent_profile_privilege_escalation()',
    'public.assign_order_number()',
    'public.record_order_status_change()',
    'public.validate_product_image_variant()'
  ];
  sig text;
  grantee text;
begin
  foreach sig in array protected loop
    foreach grantee in array array['public', 'anon', 'authenticated'] loop
      if has_function_privilege(grantee, sig, 'EXECUTE') then
        raise exception 'FAIL: % still has EXECUTE on %', grantee, sig;
      end if;
    end loop;
    if not has_function_privilege('service_role', sig, 'EXECUTE') then
      raise exception 'FAIL: service_role missing EXECUTE on %', sig;
    end if;
  end loop;

  foreach grantee in array array['public', 'anon', 'authenticated'] loop
    if has_function_privilege(
      grantee, 'public.handle_new_user_profile()', 'EXECUTE'
    ) then
      raise exception
        'FAIL: % still has EXECUTE on handle_new_user_profile',
        grantee;
    end if;
  end loop;

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

  if not has_function_privilege(
    'anon', 'public.is_staff_or_admin()', 'EXECUTE'
  ) then
    raise exception 'FAIL: anon missing EXECUTE on is_staff_or_admin';
  end if;

  raise notice 'OK: function EXECUTE contracts';
end $$;

-- ---------------------------------------------------------------------------
-- Fixtures (deterministic UUIDs; rolled back)
-- ---------------------------------------------------------------------------
select pg_temp.grants_insert_user(
  'a8000000-0000-4000-8000-000000000001',
  'grants-customer-a@example.invalid'
);
select pg_temp.grants_insert_user(
  'a8000000-0000-4000-8000-000000000002',
  'grants-customer-b@example.invalid'
);
select pg_temp.grants_insert_user(
  'a8000000-0000-4000-8000-000000000003',
  'grants-staff@example.invalid'
);
select pg_temp.grants_insert_user(
  'a8000000-0000-4000-8000-000000000004',
  'grants-admin@example.invalid'
);
select pg_temp.grants_insert_user(
  'a8000000-0000-4000-8000-000000000005',
  'grants-forged@example.invalid'
);

-- Trusted role is profiles.role only (owner/service context).
update public.profiles
set role = 'staff', full_name = 'Grants Staff'
where id = 'a8000000-0000-4000-8000-000000000003';

update public.profiles
set role = 'admin', full_name = 'Grants Admin'
where id = 'a8000000-0000-4000-8000-000000000004';

update public.profiles
set full_name = 'Grants Customer A'
where id = 'a8000000-0000-4000-8000-000000000001';

update public.profiles
set full_name = 'Grants Customer B'
where id = 'a8000000-0000-4000-8000-000000000002';

update public.profiles
set full_name = 'Grants Forged Customer'
where id = 'a8000000-0000-4000-8000-000000000005';

-- Inactive category for anon RLS denial (owner insert).
insert into public.categories (
  id, name, slug, sort_order, is_active
) values (
  'a8100000-0000-4000-8000-000000000001',
  'Grants Inactive Category',
  'grants-inactive-category',
  999,
  false
);

-- Seeded active product / draft product / active variant ids.
-- active product: 30000000-...0001, draft: 30000000-...0006
-- active variant: 40000000-...0001

insert into public.addresses (
  id, user_id, recipient_name, phone_number,
  province_name, district_name, ward_name, street_address, is_default
) values
  (
    'a8200000-0000-4000-8000-000000000001',
    'a8000000-0000-4000-8000-000000000001',
    'Customer A',
    '0908000001',
    'TP Hồ Chí Minh',
    'Quận 1',
    'Phường Bến Nghé',
    '8 Nguyễn Huệ',
    true
  ),
  (
    'a8200000-0000-4000-8000-000000000002',
    'a8000000-0000-4000-8000-000000000002',
    'Customer B',
    '0908000002',
    'Hà Nội',
    'Quận Ba Đình',
    'Phường Điện Biên',
    '8 Hoàng Diệu',
    true
  );

insert into public.orders (
  id, order_number, user_id, status,
  subtotal, discount_total, shipping_fee, grand_total,
  recipient_name, recipient_phone, shipping_address
) values (
  'a8300000-0000-4000-8000-000000000001',
  'BDM-GRANTS-A001',
  'a8000000-0000-4000-8000-000000000001',
  'pending',
  100, 0, 0, 100,
  'Customer A',
  '0908000001',
  '{"line1":"8 Nguyen Hue"}'::jsonb
);

insert into public.order_items (
  id, order_id, product_id, variant_id, product_name, variant_name, sku,
  unit_price, quantity, line_total
) values (
  'a8400000-0000-4000-8000-000000000001',
  'a8300000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001',
  'Seed Product',
  'Seed Variant',
  'GRANTS-SKU-1',
  100, 1, 100
);

-- ---------------------------------------------------------------------------
-- RLS: anon catalog reads / write denial
-- ---------------------------------------------------------------------------
do $$
declare
  v_count integer;
  v_denied boolean;
begin
  set local role anon;

  select count(*) into v_count
  from public.categories
  where id = '10000000-0000-4000-8000-000000000001';
  if v_count <> 1 then
    raise exception 'FAIL: anon cannot see active category (count=%)', v_count;
  end if;

  select count(*) into v_count
  from public.categories
  where id = 'a8100000-0000-4000-8000-000000000001';
  if v_count <> 0 then
    raise exception 'FAIL: anon can see inactive category';
  end if;

  select count(*) into v_count
  from public.products
  where id = '30000000-0000-4000-8000-000000000001';
  if v_count <> 1 then
    raise exception 'FAIL: anon cannot see active product (count=%)', v_count;
  end if;

  select count(*) into v_count
  from public.products
  where id = '30000000-0000-4000-8000-000000000006';
  if v_count <> 0 then
    raise exception 'FAIL: anon can see draft product';
  end if;

  select count(*) into v_count
  from public.product_catalog
  where id = '30000000-0000-4000-8000-000000000001';
  if v_count <> 1 then
    raise exception
      'FAIL: anon cannot read product_catalog active row (count=%)', v_count;
  end if;

  select count(*) into v_count
  from public.product_catalog
  where id = '30000000-0000-4000-8000-000000000006';
  if v_count <> 0 then
    raise exception 'FAIL: anon can see draft via product_catalog';
  end if;

  v_denied := false;
  begin
    insert into public.categories (name, slug, sort_order)
    values ('Anon Write', 'anon-write', 1);
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate = '42501' then
        v_denied := true;
      else
        reset role;
        raise exception
          'FAIL: anon category INSERT unexpected SQLSTATE %: %',
          sqlstate, sqlerrm;
      end if;
  end;
  if not v_denied then
    reset role;
    raise exception 'FAIL: anon INSERT on categories succeeded';
  end if;

  v_denied := false;
  begin
    select count(*) into v_count from public.inventory;
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate = '42501' then
        v_denied := true;
      else
        reset role;
        raise exception
          'FAIL: anon inventory SELECT unexpected SQLSTATE %: %',
          sqlstate, sqlerrm;
      end if;
  end;
  if not v_denied then
    reset role;
    raise exception 'FAIL: anon SELECT on inventory succeeded';
  end if;

  -- Public RPC still works without inventory table grant.
  select count(*) into v_count
  from public.get_variant_availability(
    '40000000-0000-4000-8000-000000000001'
  );
  if v_count <> 1 then
    raise exception
      'FAIL: anon get_variant_availability failed (count=%)', v_count;
  end if;

  reset role;
  raise notice 'OK: anon RLS catalog read / write denial';
exception
  when others then
    reset role;
    raise;
end $$;

-- ---------------------------------------------------------------------------
-- RLS: customer own address / favorite / cart / order reads + cross-user denial
-- ---------------------------------------------------------------------------
do $$
declare
  v_customer_a uuid := 'a8000000-0000-4000-8000-000000000001';
  v_customer_b uuid := 'a8000000-0000-4000-8000-000000000002';
  v_addr_a uuid := 'a8200000-0000-4000-8000-000000000001';
  v_addr_b uuid := 'a8200000-0000-4000-8000-000000000002';
  v_order_a uuid := 'a8300000-0000-4000-8000-000000000001';
  v_product_id uuid := '30000000-0000-4000-8000-000000000001';
  v_cart_id uuid := 'a8600000-0000-4000-8000-000000000001';
  v_item_id uuid := 'a8700000-0000-4000-8000-000000000001';
  v_count integer;
  v_name text;
  v_denied boolean;
  v_reserved integer;
  v_status text;
  v_subtotal numeric;
begin
  -- Customer A: own CRUD flows.
  perform pg_temp.grants_set_auth(v_customer_a);

  select count(*) into v_count from public.addresses where id = v_addr_a;
  if v_count <> 1 then
    raise exception 'FAIL: customer A cannot SELECT own address';
  end if;

  update public.addresses
  set street_address = '8 Nguyễn Huệ Updated'
  where id = v_addr_a;
  if not found then
    raise exception 'FAIL: customer A cannot UPDATE own address';
  end if;

  insert into public.favorites (user_id, product_id)
  values (v_customer_a, v_product_id);

  insert into public.carts (id, user_id, status)
  values (v_cart_id, v_customer_a, 'active');

  insert into public.cart_items (
    id, cart_id, variant_id, quantity, unit_price_snapshot
  ) values (
    v_item_id,
    v_cart_id,
    '40000000-0000-4000-8000-000000000001',
    1,
    1890000
  );

  update public.cart_items set quantity = 2 where id = v_item_id;
  if not found then
    raise exception 'FAIL: customer A cannot UPDATE own cart_item';
  end if;

  select count(*) into v_count from public.orders where id = v_order_a;
  if v_count <> 1 then
    raise exception 'FAIL: customer A cannot SELECT own order';
  end if;

  select count(*) into v_count
  from public.order_items
  where order_id = v_order_a;
  if v_count <> 1 then
    raise exception 'FAIL: customer A cannot SELECT own order_items';
  end if;

  select count(*) into v_count
  from public.order_status_history
  where order_id = v_order_a;
  if v_count < 1 then
    raise exception 'FAIL: customer A cannot SELECT own order_status_history';
  end if;

  -- Cross-user denial: customer A cannot see B's address.
  select count(*) into v_count from public.addresses where id = v_addr_b;
  if v_count <> 0 then
    raise exception 'FAIL: customer A can SELECT customer B address';
  end if;

  perform pg_temp.grants_clear_auth();

  -- Customer B cannot read A's private rows.
  perform pg_temp.grants_set_auth(v_customer_b);

  select count(*) into v_count from public.addresses where id = v_addr_a;
  if v_count <> 0 then
    raise exception 'FAIL: customer B can SELECT customer A address';
  end if;

  select count(*) into v_count
  from public.favorites
  where user_id = v_customer_a and product_id = v_product_id;
  if v_count <> 0 then
    raise exception 'FAIL: customer B can SELECT customer A favorite';
  end if;

  select count(*) into v_count from public.carts where id = v_cart_id;
  if v_count <> 0 then
    raise exception 'FAIL: customer B can SELECT customer A cart';
  end if;

  select count(*) into v_count from public.orders where id = v_order_a;
  if v_count <> 0 then
    raise exception 'FAIL: customer B can SELECT customer A order';
  end if;

  v_denied := false;
  begin
    update public.addresses
    set street_address = 'Hacked'
    where id = v_addr_a;
    if not found then
      v_denied := true;
    end if;
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate = '42501' then
        v_denied := true;
      else
        perform pg_temp.grants_clear_auth();
        raise exception
          'FAIL: cross-user address UPDATE unexpected SQLSTATE %: %',
          sqlstate, sqlerrm;
      end if;
  end;
  if not v_denied then
    perform pg_temp.grants_clear_auth();
    raise exception 'FAIL: customer B mutated customer A address';
  end if;

  perform pg_temp.grants_clear_auth();

  -- Confirm address unchanged.
  select street_address into v_name
  from public.addresses where id = v_addr_a;
  if v_name is distinct from '8 Nguyễn Huệ Updated' then
    raise exception 'FAIL: customer A address mutated by cross-user attempt';
  end if;

  -- Trusted order boundary: customer cannot INSERT orders / mutate protected.
  -- Capture inventory baseline as owner before customer role switch.
  perform pg_temp.grants_clear_auth();
  select quantity_reserved into v_reserved
  from public.inventory
  where variant_id = '40000000-0000-4000-8000-000000000001';

  perform pg_temp.grants_set_auth(v_customer_a);

  v_denied := false;
  begin
    insert into public.orders (
      order_number, user_id, subtotal, discount_total, shipping_fee, grand_total,
      recipient_name, recipient_phone, shipping_address
    ) values (
      'BDM-GRANTS-DIRECT',
      v_customer_a,
      50, 0, 0, 50,
      'Customer A', '0908000001', '{}'::jsonb
    );
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate = '42501' then
        v_denied := true;
      else
        perform pg_temp.grants_clear_auth();
        raise exception
          'FAIL: customer order INSERT unexpected SQLSTATE %: %',
          sqlstate, sqlerrm;
      end if;
  end;
  if not v_denied then
    perform pg_temp.grants_clear_auth();
    raise exception 'FAIL: customer direct INSERT on orders succeeded';
  end if;

  v_denied := false;
  begin
    update public.inventory
    set quantity_reserved = quantity_reserved + 1
    where variant_id = '40000000-0000-4000-8000-000000000001';
    if not found then
      v_denied := true;
    end if;
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate = '42501' then
        v_denied := true;
      else
        perform pg_temp.grants_clear_auth();
        raise exception
          'FAIL: customer inventory UPDATE unexpected SQLSTATE %: %',
          sqlstate, sqlerrm;
      end if;
  end;
  if not v_denied then
    perform pg_temp.grants_clear_auth();
    raise exception 'FAIL: customer inventory UPDATE mutated rows';
  end if;

  perform pg_temp.grants_clear_auth();

  if (
    select quantity_reserved
    from public.inventory
    where variant_id = '40000000-0000-4000-8000-000000000001'
  ) is distinct from v_reserved then
    raise exception 'FAIL: customer inventory UPDATE mutated reserved qty';
  end if;

  -- Protected order field update must not mutate.
  select status, subtotal into v_status, v_subtotal
  from public.orders where id = v_order_a;

  perform pg_temp.grants_set_auth(v_customer_a);
  v_denied := false;
  begin
    update public.orders
    set status = 'cancelled', subtotal = 1, grand_total = 1
    where id = v_order_a;
    if not found then
      v_denied := true;
    end if;
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate = '42501' then
        v_denied := true;
      else
        perform pg_temp.grants_clear_auth();
        raise exception
          'FAIL: customer order UPDATE unexpected SQLSTATE %: %',
          sqlstate, sqlerrm;
      end if;
  end;
  if not v_denied then
    perform pg_temp.grants_clear_auth();
    raise exception 'FAIL: customer UPDATE on orders succeeded';
  end if;
  perform pg_temp.grants_clear_auth();

  if (
    select status from public.orders where id = v_order_a
  ) is distinct from v_status
     or (
       select subtotal from public.orders where id = v_order_a
     ) is distinct from v_subtotal then
    raise exception 'FAIL: customer order UPDATE mutated protected fields';
  end if;

  -- Customer A cleanup delete of own favorite/cart item.
  perform pg_temp.grants_set_auth(v_customer_a);
  delete from public.cart_items where id = v_item_id;
  delete from public.favorites
  where user_id = v_customer_a and product_id = v_product_id;
  perform pg_temp.grants_clear_auth();

  raise notice 'OK: customer own-row CRUD + cross-user + trusted-order boundary';
exception
  when others then
    perform pg_temp.grants_clear_auth();
    raise;
end $$;

-- ---------------------------------------------------------------------------
-- Staff / admin workflows + forged JWT denial
-- ---------------------------------------------------------------------------
do $$
declare
  v_staff uuid := 'a8000000-0000-4000-8000-000000000003';
  v_admin uuid := 'a8000000-0000-4000-8000-000000000004';
  v_forged uuid := 'a8000000-0000-4000-8000-000000000005';
  v_cat_id uuid := 'a8100000-0000-4000-8000-000000000002';
  v_order_id uuid := 'a8300000-0000-4000-8000-000000000002';
  v_count integer;
  v_on_hand integer;
  v_denied boolean;
begin
  -- Staff catalog write.
  perform pg_temp.grants_set_auth(v_staff);

  insert into public.categories (id, name, slug, sort_order, is_active)
  values (v_cat_id, 'Grants Staff Category', 'grants-staff-category', 998, true);

  update public.categories
  set description = 'staff-updated'
  where id = v_cat_id;
  if not found then
    raise exception 'FAIL: staff cannot UPDATE category';
  end if;

  select quantity_on_hand into v_on_hand
  from public.inventory
  where variant_id = '40000000-0000-4000-8000-000000000001';

  update public.inventory
  set quantity_on_hand = quantity_on_hand + 1
  where variant_id = '40000000-0000-4000-8000-000000000001';
  if not found then
    raise exception 'FAIL: staff cannot UPDATE inventory';
  end if;

  insert into public.orders (
    id, order_number, user_id,
    subtotal, discount_total, shipping_fee, grand_total,
    recipient_name, recipient_phone, shipping_address
  ) values (
    v_order_id,
    'BDM-GRANTS-STAFF1',
    'a8000000-0000-4000-8000-000000000001',
    200, 0, 0, 200,
    'Staff Created',
    '0908000003',
    '{"line1":"staff"}'::jsonb
  );

  insert into public.order_items (
    order_id, product_id, variant_id, product_name, variant_name, sku,
    unit_price, quantity, line_total
  ) values (
    v_order_id,
    '30000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    'Staff Product',
    'Staff Variant',
    'GRANTS-STAFF-1',
    200, 1, 200
  );

  perform pg_temp.grants_clear_auth();

  if (
    select quantity_on_hand
    from public.inventory
    where variant_id = '40000000-0000-4000-8000-000000000001'
  ) is distinct from v_on_hand + 1 then
    raise exception 'FAIL: staff inventory UPDATE did not persist';
  end if;

  -- Admin can select inactive category (staff-or-admin SELECT path).
  perform pg_temp.grants_set_auth(v_admin);
  select count(*) into v_count
  from public.categories
  where id = 'a8100000-0000-4000-8000-000000000001';
  if v_count <> 1 then
    raise exception 'FAIL: admin cannot see inactive category';
  end if;
  perform pg_temp.grants_clear_auth();

  -- Forged JWT role claims do not grant staff authority.
  perform pg_temp.grants_set_auth_forged_staff(v_forged);

  v_denied := false;
  begin
    insert into public.categories (name, slug, sort_order)
    values ('Forged Staff Cat', 'forged-staff-cat', 1);
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate = '42501' then
        v_denied := true;
      else
        perform pg_temp.grants_clear_auth();
        raise exception
          'FAIL: forged staff INSERT unexpected SQLSTATE %: %',
          sqlstate, sqlerrm;
      end if;
  end;
  if not v_denied then
    perform pg_temp.grants_clear_auth();
    raise exception 'FAIL: forged JWT obtained staff catalog INSERT';
  end if;

  v_denied := false;
  begin
    update public.inventory
    set quantity_on_hand = quantity_on_hand + 1
    where variant_id = '40000000-0000-4000-8000-000000000001';
    if not found then
      v_denied := true;
    end if;
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate = '42501' then
        v_denied := true;
      else
        perform pg_temp.grants_clear_auth();
        raise exception
          'FAIL: forged inventory UPDATE unexpected SQLSTATE %: %',
          sqlstate, sqlerrm;
      end if;
  end;
  if not v_denied then
    perform pg_temp.grants_clear_auth();
    raise exception 'FAIL: forged JWT mutated inventory';
  end if;

  perform pg_temp.grants_clear_auth();

  raise notice 'OK: staff/admin workflows + forged JWT denial';
exception
  when others then
    perform pg_temp.grants_clear_auth();
    raise;
end $$;

rollback;

\echo '== done =='
