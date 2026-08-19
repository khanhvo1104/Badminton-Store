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

-- Assert exact table privilege presence/absence (grant layer only).
create or replace function pg_temp.assert_table_priv(
  p_role text,
  p_table text,
  p_priv text,
  p_expected boolean
)
returns void
language plpgsql
as $$
declare
  v_has boolean;
begin
  v_has := has_table_privilege(
    p_role,
    format('public.%I', p_table),
    p_priv
  );
  if p_expected and not v_has then
    raise exception
      'FAIL: % missing % on public.%',
      p_role, p_priv, p_table;
  end if;
  if (not p_expected) and v_has then
    raise exception
      'FAIL: % unexpectedly has % on public.%',
      p_role, p_priv, p_table;
  end if;
end;
$$;

-- Apply a 4-tuple privilege mask: SELECT/INSERT/UPDATE/DELETE as booleans.
create or replace function pg_temp.assert_siud(
  p_role text,
  p_table text,
  p_select boolean,
  p_insert boolean,
  p_update boolean,
  p_delete boolean
)
returns void
language plpgsql
as $$
begin
  perform pg_temp.assert_table_priv(p_role, p_table, 'SELECT', p_select);
  perform pg_temp.assert_table_priv(p_role, p_table, 'INSERT', p_insert);
  perform pg_temp.assert_table_priv(p_role, p_table, 'UPDATE', p_update);
  perform pg_temp.assert_table_priv(p_role, p_table, 'DELETE', p_delete);
end;
$$;

-- ---------------------------------------------------------------------------
-- Grant-layer: exhaustive least-privilege matrix (independent of RLS)
-- ---------------------------------------------------------------------------
do $$
declare
  app_objects text[] := array[
    'profiles', 'addresses', 'categories', 'brands', 'products',
    'product_variants', 'product_images', 'inventory', 'inventory_history',
    'favorites',
    'carts', 'cart_items', 'orders', 'order_items', 'order_status_history',
    'notifications', 'product_catalog', 'inventory_availability'
  ];
  t text;
  priv text;
  table_select_grantee text;
  table_update_grantee text;
  safe_cols text[] := array[
    'id', 'product_id', 'sku', 'name', 'color_name', 'color_hex',
    'racket_weight_class', 'grip_size', 'shoe_size', 'clothing_size',
    'unit', 'price', 'compare_at_price', 'attributes', 'is_default',
    'is_active', 'sort_order'
  ];
  notification_immutable_cols text[] := array[
    'id', 'user_id', 'type', 'title', 'body', 'payload', 'created_at'
  ];
  col text;
begin
  -- PUBLIC: no residual table/view SIUD on any application object.
  foreach t in array app_objects loop
    foreach priv in array array['SELECT', 'INSERT', 'UPDATE', 'DELETE'] loop
      perform pg_temp.assert_table_priv('public', t, priv, false);
    end loop;
  end loop;

  -- anon: catalog-safe reads only; no writes anywhere.
  perform pg_temp.assert_siud('anon', 'categories', true, false, false, false);
  perform pg_temp.assert_siud('anon', 'brands', true, false, false, false);
  perform pg_temp.assert_siud('anon', 'products', true, false, false, false);
  perform pg_temp.assert_siud('anon', 'product_images', true, false, false, false);
  perform pg_temp.assert_siud(
    'anon', 'product_catalog', true, false, false, false
  );

  perform pg_temp.assert_siud('anon', 'profiles', false, false, false, false);
  perform pg_temp.assert_siud('anon', 'addresses', false, false, false, false);
  perform pg_temp.assert_siud('anon', 'favorites', false, false, false, false);
  perform pg_temp.assert_siud('anon', 'carts', false, false, false, false);
  perform pg_temp.assert_siud('anon', 'cart_items', false, false, false, false);
  perform pg_temp.assert_siud('anon', 'orders', false, false, false, false);
  perform pg_temp.assert_siud('anon', 'order_items', false, false, false, false);
  perform pg_temp.assert_siud(
    'anon', 'order_status_history', false, false, false, false
  );
  perform pg_temp.assert_siud('anon', 'inventory', false, false, false, false);
  perform pg_temp.assert_siud(
    'anon', 'inventory_history', false, false, false, false
  );
  perform pg_temp.assert_siud(
    'anon', 'inventory_availability', false, false, false, false
  );
  perform pg_temp.assert_siud(
    'anon', 'notifications', false, false, false, false
  );

  -- product_variants: no table-wide SELECT for public roles; no writes for anon.
  for table_select_grantee in
    select grantee
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'product_variants'
      and privilege_type = 'SELECT'
      and grantee in ('PUBLIC', 'anon', 'authenticated')
  loop
    raise exception
      'FAIL: % still has table-wide SELECT on product_variants',
      table_select_grantee;
  end loop;

  perform pg_temp.assert_table_priv('anon', 'product_variants', 'INSERT', false);
  perform pg_temp.assert_table_priv('anon', 'product_variants', 'UPDATE', false);
  perform pg_temp.assert_table_priv('anon', 'product_variants', 'DELETE', false);

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

  -- authenticated: exact positive + negative operation matrix.
  perform pg_temp.assert_siud(
    'authenticated', 'profiles', true, false, true, false
  );
  perform pg_temp.assert_siud(
    'authenticated', 'addresses', true, true, true, true
  );
  perform pg_temp.assert_siud(
    'authenticated', 'categories', true, true, true, true
  );
  perform pg_temp.assert_siud(
    'authenticated', 'brands', true, true, true, true
  );
  perform pg_temp.assert_siud(
    'authenticated', 'products', true, true, true, true
  );
  perform pg_temp.assert_siud(
    'authenticated', 'product_images', true, true, true, true
  );
  perform pg_temp.assert_siud(
    'authenticated', 'inventory', true, true, true, true
  );
  perform pg_temp.assert_siud(
    'authenticated', 'inventory_history', true, false, false, false
  );
  -- Favorites: SELECT/INSERT/DELETE only (no UPDATE grant).
  perform pg_temp.assert_siud(
    'authenticated', 'favorites', true, true, false, true
  );
  perform pg_temp.assert_siud(
    'authenticated', 'carts', true, true, true, true
  );
  perform pg_temp.assert_siud(
    'authenticated', 'cart_items', true, true, true, true
  );
  -- Orders: SELECT/INSERT/UPDATE (no DELETE).
  perform pg_temp.assert_siud(
    'authenticated', 'orders', true, true, true, false
  );
  -- Order items / history: SELECT/INSERT only (no UPDATE/DELETE).
  perform pg_temp.assert_siud(
    'authenticated', 'order_items', true, true, false, false
  );
  perform pg_temp.assert_siud(
    'authenticated', 'order_status_history', true, true, false, false
  );
  perform pg_temp.assert_siud(
    'authenticated', 'product_catalog', true, false, false, false
  );
  perform pg_temp.assert_siud(
    'authenticated', 'inventory_availability', false, false, false, false
  );

  -- Notifications: SELECT + column UPDATE(is_read) only. No table-wide UPDATE
  -- / INSERT / DELETE. Do not use assert_siud for UPDATE.
  perform pg_temp.assert_table_priv(
    'authenticated', 'notifications', 'SELECT', true
  );
  perform pg_temp.assert_table_priv(
    'authenticated', 'notifications', 'INSERT', false
  );
  perform pg_temp.assert_table_priv(
    'authenticated', 'notifications', 'DELETE', false
  );
  for table_update_grantee in
    select grantee
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'notifications'
      and privilege_type = 'UPDATE'
      and grantee in ('PUBLIC', 'anon', 'authenticated')
  loop
    raise exception
      'FAIL: % still has table-wide UPDATE on notifications',
      table_update_grantee;
  end loop;
  if not has_column_privilege(
    'authenticated', 'public.notifications', 'is_read', 'UPDATE'
  ) then
    raise exception
      'FAIL: authenticated missing UPDATE on notifications.is_read';
  end if;
  foreach col in array notification_immutable_cols loop
    if has_column_privilege(
      'authenticated', 'public.notifications', col, 'UPDATE'
    ) then
      raise exception
        'FAIL: authenticated can UPDATE notifications.%', col;
    end if;
  end loop;

  -- product_variants: column SELECT + staff writes; no table-wide SELECT.
  perform pg_temp.assert_table_priv(
    'authenticated', 'product_variants', 'INSERT', true
  );
  perform pg_temp.assert_table_priv(
    'authenticated', 'product_variants', 'UPDATE', true
  );
  perform pg_temp.assert_table_priv(
    'authenticated', 'product_variants', 'DELETE', true
  );

  if has_column_privilege(
    'authenticated', 'public.product_variants', 'cost_price', 'SELECT'
  ) then
    raise exception
      'FAIL: authenticated can SELECT product_variants.cost_price';
  end if;

  foreach col in array safe_cols loop
    if not has_column_privilege(
      'authenticated', 'public.product_variants', col, 'SELECT'
    ) then
      raise exception
        'FAIL: authenticated missing SELECT on product_variants.%',
        col;
    end if;
  end loop;

  -- service_role retains full SIUD on every application table/view + cost_price.
  foreach t in array app_objects loop
    perform pg_temp.assert_siud('service_role', t, true, true, true, true);
  end loop;

  if not has_column_privilege(
    'service_role', 'public.product_variants', 'cost_price', 'SELECT'
  ) then
    raise exception
      'FAIL: service_role lost SELECT on product_variants.cost_price';
  end if;

  raise notice 'OK: exhaustive PUBLIC/anon/authenticated/service_role grants';
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
    'public.validate_product_image_variant()',
    'public.prevent_inventory_history_mutation()'
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

  -- Catalog RPCs: anon + authenticated + service_role.
  foreach grantee in array array['anon', 'authenticated', 'service_role'] loop
    if not has_function_privilege(
      grantee, 'public.get_variant_availability(uuid)', 'EXECUTE'
    ) then
      raise exception 'FAIL: % missing EXECUTE on get_variant_availability',
        grantee;
    end if;
    if not has_function_privilege(
      grantee, 'public.search_products(text, integer)', 'EXECUTE'
    ) then
      raise exception 'FAIL: % missing EXECUTE on search_products', grantee;
    end if;
  end loop;

  if has_function_privilege(
    'public', 'public.get_variant_availability(uuid)', 'EXECUTE'
  ) then
    raise exception 'FAIL: PUBLIC has EXECUTE on get_variant_availability';
  end if;
  if has_function_privilege(
    'public', 'public.search_products(text, integer)', 'EXECUTE'
  ) then
    raise exception 'FAIL: PUBLIC has EXECUTE on search_products';
  end if;

  -- checkout_cod: authenticated + service_role only.
  if has_function_privilege(
    'public', 'public.checkout_cod(uuid, text)', 'EXECUTE'
  ) then
    raise exception 'FAIL: PUBLIC has EXECUTE on checkout_cod';
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

  if has_function_privilege(
    'public',
    'public.list_cms_products(text, uuid, uuid, text, text, text, integer, integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: PUBLIC has EXECUTE on list_cms_products';
  end if;
  if has_function_privilege(
    'anon',
    'public.list_cms_products(text, uuid, uuid, text, text, text, integer, integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: anon has EXECUTE on list_cms_products';
  end if;
  if not has_function_privilege(
    'authenticated',
    'public.list_cms_products(text, uuid, uuid, text, text, text, integer, integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: authenticated missing EXECUTE on list_cms_products';
  end if;
  if not has_function_privilege(
    'service_role',
    'public.list_cms_products(text, uuid, uuid, text, text, text, integer, integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: service_role missing EXECUTE on list_cms_products';
  end if;

  if has_function_privilege(
    'public',
    'public.save_cms_product_variant(uuid, uuid, text, text, text, text, text, text, text, text, text, numeric, numeric, text, numeric, text, text, jsonb, boolean, boolean, integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: PUBLIC has EXECUTE on save_cms_product_variant';
  end if;
  if has_function_privilege(
    'anon',
    'public.save_cms_product_variant(uuid, uuid, text, text, text, text, text, text, text, text, text, numeric, numeric, text, numeric, text, text, jsonb, boolean, boolean, integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: anon has EXECUTE on save_cms_product_variant';
  end if;
  if not has_function_privilege(
    'authenticated',
    'public.save_cms_product_variant(uuid, uuid, text, text, text, text, text, text, text, text, text, numeric, numeric, text, numeric, text, text, jsonb, boolean, boolean, integer)',
    'EXECUTE'
  ) then
    raise exception
      'FAIL: authenticated missing EXECUTE on save_cms_product_variant';
  end if;
  if not has_function_privilege(
    'service_role',
    'public.save_cms_product_variant(uuid, uuid, text, text, text, text, text, text, text, text, text, numeric, numeric, text, numeric, text, text, jsonb, boolean, boolean, integer)',
    'EXECUTE'
  ) then
    raise exception
      'FAIL: service_role missing EXECUTE on save_cms_product_variant';
  end if;

  if has_function_privilege(
    'public',
    'public.list_cms_inventory(text, text, text, integer, integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: PUBLIC has EXECUTE on list_cms_inventory';
  end if;
  if has_function_privilege(
    'anon',
    'public.list_cms_inventory(text, text, text, integer, integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: anon has EXECUTE on list_cms_inventory';
  end if;
  if not has_function_privilege(
    'authenticated',
    'public.list_cms_inventory(text, text, text, integer, integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: authenticated missing EXECUTE on list_cms_inventory';
  end if;
  if not has_function_privilege(
    'service_role',
    'public.list_cms_inventory(text, text, text, integer, integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: service_role missing EXECUTE on list_cms_inventory';
  end if;

  if has_function_privilege(
    'public',
    'public.adjust_cms_inventory(uuid, text, integer, boolean, text, text)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: PUBLIC has EXECUTE on adjust_cms_inventory';
  end if;
  if has_function_privilege(
    'anon',
    'public.adjust_cms_inventory(uuid, text, integer, boolean, text, text)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: anon has EXECUTE on adjust_cms_inventory';
  end if;
  if not has_function_privilege(
    'authenticated',
    'public.adjust_cms_inventory(uuid, text, integer, boolean, text, text)',
    'EXECUTE'
  ) then
    raise exception
      'FAIL: authenticated missing EXECUTE on adjust_cms_inventory';
  end if;
  if not has_function_privilege(
    'service_role',
    'public.adjust_cms_inventory(uuid, text, integer, boolean, text, text)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: service_role missing EXECUTE on adjust_cms_inventory';
  end if;

  if has_function_privilege(
    'public',
    'public.set_cms_product_image_primary(uuid, uuid)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: PUBLIC has EXECUTE on set_cms_product_image_primary';
  end if;
  if has_function_privilege(
    'anon',
    'public.set_cms_product_image_primary(uuid, uuid)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: anon has EXECUTE on set_cms_product_image_primary';
  end if;
  if not has_function_privilege(
    'authenticated',
    'public.set_cms_product_image_primary(uuid, uuid)',
    'EXECUTE'
  ) then
    raise exception
      'FAIL: authenticated missing EXECUTE on set_cms_product_image_primary';
  end if;
  if not has_function_privilege(
    'service_role',
    'public.set_cms_product_image_primary(uuid, uuid)',
    'EXECUTE'
  ) then
    raise exception
      'FAIL: service_role missing EXECUTE on set_cms_product_image_primary';
  end if;

  if has_function_privilege(
    'public',
    'public.reorder_cms_product_images(uuid, uuid[])',
    'EXECUTE'
  ) then
    raise exception 'FAIL: PUBLIC has EXECUTE on reorder_cms_product_images';
  end if;
  if has_function_privilege(
    'anon',
    'public.reorder_cms_product_images(uuid, uuid[])',
    'EXECUTE'
  ) then
    raise exception 'FAIL: anon has EXECUTE on reorder_cms_product_images';
  end if;
  if not has_function_privilege(
    'authenticated',
    'public.reorder_cms_product_images(uuid, uuid[])',
    'EXECUTE'
  ) then
    raise exception
      'FAIL: authenticated missing EXECUTE on reorder_cms_product_images';
  end if;
  if not has_function_privilege(
    'service_role',
    'public.reorder_cms_product_images(uuid, uuid[])',
    'EXECUTE'
  ) then
    raise exception
      'FAIL: service_role missing EXECUTE on reorder_cms_product_images';
  end if;

  -- Policy helpers remain executable by Data API roles.
  foreach grantee in array array['anon', 'authenticated', 'service_role'] loop
    if not has_function_privilege(
      grantee, 'public.is_staff_or_admin()', 'EXECUTE'
    ) then
      raise exception 'FAIL: % missing EXECUTE on is_staff_or_admin', grantee;
    end if;
    if not has_function_privilege(
      grantee, 'public.is_admin()', 'EXECUTE'
    ) then
      raise exception 'FAIL: % missing EXECUTE on is_admin', grantee;
    end if;
  end loop;

  -- Historical helpers: no anon EXECUTE; authenticated + service_role only.
  foreach sig in array array[
    'public.set_updated_at()',
    'public.generate_order_number()',
    'public.cart_items_enforce_active_cart()'
  ] loop
    if has_function_privilege('public', sig, 'EXECUTE') then
      raise exception 'FAIL: PUBLIC has EXECUTE on %', sig;
    end if;
    if has_function_privilege('anon', sig, 'EXECUTE') then
      raise exception 'FAIL: anon has EXECUTE on %', sig;
    end if;
    if not has_function_privilege('authenticated', sig, 'EXECUTE') then
      raise exception 'FAIL: authenticated missing EXECUTE on %', sig;
    end if;
    if not has_function_privilege('service_role', sig, 'EXECUTE') then
      raise exception 'FAIL: service_role missing EXECUTE on %', sig;
    end if;
  end loop;

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
  v_order_item_a uuid := 'a8400000-0000-4000-8000-000000000001';
  v_product_id uuid := '30000000-0000-4000-8000-000000000001';
  v_cart_id uuid := 'a8600000-0000-4000-8000-000000000001';
  v_item_id uuid := 'a8700000-0000-4000-8000-000000000001';
  v_count integer;
  v_item_count integer;
  v_history_count integer;
  v_name text;
  v_denied boolean;
  v_reserved integer;
  v_status text;
  v_subtotal numeric;
  v_qty integer;
  v_cart_status text;
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

  -- Baselines for cross-user mutation checks (owner context).
  select quantity into v_qty from public.cart_items where id = v_item_id;
  select status into v_cart_status from public.carts where id = v_cart_id;

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

  select count(*) into v_count from public.cart_items where id = v_item_id;
  if v_count <> 0 then
    raise exception 'FAIL: customer B can SELECT customer A cart_item';
  end if;

  select count(*) into v_count from public.orders where id = v_order_a;
  if v_count <> 0 then
    raise exception 'FAIL: customer B can SELECT customer A order';
  end if;

  select count(*) into v_count
  from public.order_items where order_id = v_order_a;
  if v_count <> 0 then
    raise exception 'FAIL: customer B can SELECT customer A order_items';
  end if;

  select count(*) into v_count
  from public.order_status_history where order_id = v_order_a;
  if v_count <> 0 then
    raise exception
      'FAIL: customer B can SELECT customer A order_status_history';
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

  -- Cross-user favorite DELETE must not remove A's row.
  v_denied := false;
  begin
    delete from public.favorites
    where user_id = v_customer_a and product_id = v_product_id;
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
          'FAIL: cross-user favorite DELETE unexpected SQLSTATE %: %',
          sqlstate, sqlerrm;
      end if;
  end;
  if not v_denied then
    perform pg_temp.grants_clear_auth();
    raise exception 'FAIL: customer B deleted customer A favorite';
  end if;

  -- Cross-user cart UPDATE must not mutate.
  v_denied := false;
  begin
    update public.carts set status = 'abandoned' where id = v_cart_id;
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
          'FAIL: cross-user cart UPDATE unexpected SQLSTATE %: %',
          sqlstate, sqlerrm;
      end if;
  end;
  if not v_denied then
    perform pg_temp.grants_clear_auth();
    raise exception 'FAIL: customer B mutated customer A cart';
  end if;

  -- Cross-user cart_item UPDATE/DELETE must not mutate.
  v_denied := false;
  begin
    update public.cart_items set quantity = 99 where id = v_item_id;
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
          'FAIL: cross-user cart_item UPDATE unexpected SQLSTATE %: %',
          sqlstate, sqlerrm;
      end if;
  end;
  if not v_denied then
    perform pg_temp.grants_clear_auth();
    raise exception 'FAIL: customer B mutated customer A cart_item';
  end if;

  v_denied := false;
  begin
    delete from public.cart_items where id = v_item_id;
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
          'FAIL: cross-user cart_item DELETE unexpected SQLSTATE %: %',
          sqlstate, sqlerrm;
      end if;
  end;
  if not v_denied then
    perform pg_temp.grants_clear_auth();
    raise exception 'FAIL: customer B deleted customer A cart_item';
  end if;

  perform pg_temp.grants_clear_auth();

  -- Confirm private rows unchanged after cross-user attempts.
  select street_address into v_name
  from public.addresses where id = v_addr_a;
  if v_name is distinct from '8 Nguyễn Huệ Updated' then
    raise exception 'FAIL: customer A address mutated by cross-user attempt';
  end if;

  if (
    select count(*)
    from public.favorites
    where user_id = v_customer_a and product_id = v_product_id
  ) <> 1 then
    raise exception 'FAIL: customer A favorite mutated by cross-user attempt';
  end if;

  if (
    select status from public.carts where id = v_cart_id
  ) is distinct from v_cart_status then
    raise exception 'FAIL: customer A cart mutated by cross-user attempt';
  end if;

  if (
    select quantity from public.cart_items where id = v_item_id
  ) is distinct from v_qty then
    raise exception
      'FAIL: customer A cart_item mutated by cross-user attempt';
  end if;

  -- Trusted order boundary: customer cannot INSERT orders / items / history
  -- or mutate protected fields / inventory.
  select quantity_reserved into v_reserved
  from public.inventory
  where variant_id = '40000000-0000-4000-8000-000000000001';

  select count(*) into v_item_count
  from public.order_items where order_id = v_order_a;
  select count(*) into v_history_count
  from public.order_status_history where order_id = v_order_a;

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

  -- Direct order_items INSERT (staff grant exists; customer RLS must deny).
  v_denied := false;
  begin
    insert into public.order_items (
      order_id, product_id, variant_id, product_name, variant_name, sku,
      unit_price, quantity, line_total
    ) values (
      v_order_a,
      v_product_id,
      '40000000-0000-4000-8000-000000000001',
      'Customer Direct Item',
      'Variant',
      'GRANTS-CUST-DIRECT',
      50, 1, 50
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
          'FAIL: customer order_items INSERT unexpected SQLSTATE %: %',
          sqlstate, sqlerrm;
      end if;
  end;
  if not v_denied then
    perform pg_temp.grants_clear_auth();
    raise exception 'FAIL: customer direct INSERT on order_items succeeded';
  end if;

  -- Direct order_status_history INSERT must fail for customers.
  v_denied := false;
  begin
    insert into public.order_status_history (
      order_id, from_status, to_status, note
    ) values (
      v_order_a, 'pending', 'cancelled', 'customer-direct'
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
          'FAIL: customer order_status_history INSERT unexpected SQLSTATE %: %',
          sqlstate, sqlerrm;
      end if;
  end;
  if not v_denied then
    perform pg_temp.grants_clear_auth();
    raise exception
      'FAIL: customer direct INSERT on order_status_history succeeded';
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

  if (
    select count(*) from public.order_items where order_id = v_order_a
  ) is distinct from v_item_count then
    raise exception 'FAIL: customer order_items INSERT mutated rows';
  end if;

  if (
    select count(*)
    from public.order_status_history where order_id = v_order_a
  ) is distinct from v_history_count then
    raise exception 'FAIL: customer order_status_history INSERT mutated rows';
  end if;

  if not exists (
    select 1 from public.order_items where id = v_order_item_a
  ) then
    raise exception 'FAIL: seeded order_item missing after customer attempts';
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
  v_admin_cat_id uuid := 'a8100000-0000-4000-8000-000000000003';
  v_order_id uuid := 'a8300000-0000-4000-8000-000000000002';
  v_order_a uuid := 'a8300000-0000-4000-8000-000000000001';
  v_history_id uuid := 'a8500000-0000-4000-8000-000000000001';
  v_count integer;
  v_on_hand integer;
  v_denied boolean;
  v_status text;
  v_history_count integer;
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

  -- Staff order UPDATE + status-history INSERT (trusted workflows).
  select status into v_status from public.orders where id = v_order_a;
  select count(*) into v_history_count
  from public.order_status_history where order_id = v_order_a;

  update public.orders
  set status = 'confirmed'
  where id = v_order_a;
  if not found then
    raise exception 'FAIL: staff cannot UPDATE order status';
  end if;

  -- Trigger may already append history; explicit staff INSERT must still work.
  insert into public.order_status_history (
    id, order_id, from_status, to_status, changed_by, note
  ) values (
    v_history_id,
    v_order_a,
    v_status,
    'confirmed',
    v_staff,
    'staff-status-change'
  );

  perform pg_temp.grants_clear_auth();

  if (
    select quantity_on_hand
    from public.inventory
    where variant_id = '40000000-0000-4000-8000-000000000001'
  ) is distinct from v_on_hand + 1 then
    raise exception 'FAIL: staff inventory UPDATE did not persist';
  end if;

  if (
    select status from public.orders where id = v_order_a
  ) is distinct from 'confirmed' then
    raise exception 'FAIL: staff order UPDATE did not persist';
  end if;

  if (
    select count(*)
    from public.order_status_history where id = v_history_id
  ) <> 1 then
    raise exception 'FAIL: staff order_status_history INSERT did not persist';
  end if;

  if (
    select count(*)
    from public.order_status_history where order_id = v_order_a
  ) <= v_history_count then
    raise exception 'FAIL: staff status history count did not increase';
  end if;

  -- Admin write workflows (trusted profiles.role = admin).
  perform pg_temp.grants_set_auth(v_admin);

  select count(*) into v_count
  from public.categories
  where id = 'a8100000-0000-4000-8000-000000000001';
  if v_count <> 1 then
    raise exception 'FAIL: admin cannot see inactive category';
  end if;

  insert into public.categories (id, name, slug, sort_order, is_active)
  values (
    v_admin_cat_id,
    'Grants Admin Category',
    'grants-admin-category',
    997,
    true
  );

  update public.categories
  set description = 'admin-updated'
  where id = v_admin_cat_id;
  if not found then
    raise exception 'FAIL: admin cannot UPDATE category';
  end if;

  update public.inventory
  set quantity_on_hand = quantity_on_hand + 1
  where variant_id = '40000000-0000-4000-8000-000000000001';
  if not found then
    raise exception 'FAIL: admin cannot UPDATE inventory';
  end if;

  update public.orders
  set status = 'preparing'
  where id = v_order_a;
  if not found then
    raise exception 'FAIL: admin cannot UPDATE order status';
  end if;

  insert into public.order_status_history (
    order_id, from_status, to_status, changed_by, note
  ) values (
    v_order_a,
    'confirmed',
    'preparing',
    v_admin,
    'admin-status-change'
  );

  perform pg_temp.grants_clear_auth();

  if (
    select description from public.categories where id = v_admin_cat_id
  ) is distinct from 'admin-updated' then
    raise exception 'FAIL: admin category UPDATE did not persist';
  end if;

  if (
    select status from public.orders where id = v_order_a
  ) is distinct from 'preparing' then
    raise exception 'FAIL: admin order UPDATE did not persist';
  end if;

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
