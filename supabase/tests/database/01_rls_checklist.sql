-- Executable regression: RLS, Storage, RPC, and privilege matrix (TASK-006).
--
-- Separates grant-layer assertions from role-switched RLS / Storage behavior.
-- Fixtures use TASK-006-specific UUIDs and roll back with the transaction.
--
-- Run against an already migrated + seeded disposable local database:
--   bash supabase/tests/database/01_rls_checklist.sh
-- or:
--   docker exec -i supabase_db_Badminton-Store psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 < supabase/tests/database/01_rls_checklist.sql
--
-- Do not print tokens, secrets, JWTs, cost_price values, inventory internals,
-- or sensitive row payloads. Notices report scenario labels / counts only.
-- Complements TASK-002 (02_*) and TASK-004 (03_*) without duplicating them.

\set ON_ERROR_STOP on
\echo '== TASK-006 RLS / Storage / RPC / privilege regression =='

begin;

-- ---------------------------------------------------------------------------
-- Helpers (transaction-local)
-- ---------------------------------------------------------------------------
create or replace function pg_temp.rls_insert_user(
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
    crypt('task006-fixture', gen_salt('bf')),
    timezone('utc', now()),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    timezone('utc', now()),
    timezone('utc', now())
  );
end;
$$;

create or replace function pg_temp.rls_set_auth(p_user_id uuid)
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

-- Forged JWT metadata must not create staff/admin authority.
create or replace function pg_temp.rls_set_auth_forged_staff(p_user_id uuid)
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

create or replace function pg_temp.rls_set_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('role', 'anon')::text,
    true
  );
  execute 'set local role anon';
end;
$$;

create or replace function pg_temp.rls_clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

-- Accept SQLSTATE 42501, optional extra states, or zero-row mutation under RLS.
create or replace function pg_temp.assert_denied_or_zero(
  p_label text,
  p_sql text,
  p_expect_mutation boolean default true,
  p_extra_sqlstates text[] default null
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
    end if;
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate = '42501'
         or (
           p_extra_sqlstates is not null
           and sqlstate = any (p_extra_sqlstates)
         ) then
        v_denied := true;
      else
        perform pg_temp.rls_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if p_expect_mutation and not v_denied then
    perform pg_temp.rls_clear_auth();
    raise exception 'FAIL: % unexpectedly mutated rows', p_label;
  end if;
end;
$$;

create or replace function pg_temp.assert_privilege_error(
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
      v_denied := true;
    when others then
      if sqlstate = '42501' then
        v_denied := true;
      else
        perform pg_temp.rls_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.rls_clear_auth();
    raise exception 'FAIL: % expected privilege denial (42501)', p_label;
  end if;
end;
$$;

create or replace function pg_temp.assert_table_priv(
  p_role text,
  p_schema text,
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
    format('%I.%I', p_schema, p_table),
    p_priv
  );
  if p_expected and not v_has then
    raise exception
      'FAIL: % missing % on %.%',
      p_role, p_priv, p_schema, p_table;
  end if;
  if (not p_expected) and v_has then
    raise exception
      'FAIL: % unexpectedly has % on %.%',
      p_role, p_priv, p_schema, p_table;
  end if;
end;
$$;

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
  perform pg_temp.assert_table_priv(p_role, 'public', p_table, 'SELECT', p_select);
  perform pg_temp.assert_table_priv(p_role, 'public', p_table, 'INSERT', p_insert);
  perform pg_temp.assert_table_priv(p_role, 'public', p_table, 'UPDATE', p_update);
  perform pg_temp.assert_table_priv(p_role, 'public', p_table, 'DELETE', p_delete);
end;
$$;

create or replace function pg_temp.assert_count(
  p_label text,
  p_sql text,
  p_expected integer
)
returns void
language plpgsql
as $$
declare
  v_count integer;
begin
  execute p_sql into v_count;
  if v_count is distinct from p_expected then
    perform pg_temp.rls_clear_auth();
    raise exception
      'FAIL: % count=% expected=%',
      p_label, v_count, p_expected;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. Baseline security metadata
-- ---------------------------------------------------------------------------
do $$
declare
  app_tables text[] := array[
    'profiles', 'addresses', 'categories', 'brands', 'products',
    'product_variants', 'product_images', 'inventory', 'inventory_history',
    'favorites',
    'carts', 'cart_items', 'orders', 'order_items', 'order_status_history',
    'notifications'
  ];
  t text;
  v_rls boolean;
  v_invoker text;
begin
  foreach t in array app_tables loop
    select c.relrowsecurity into v_rls
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = t;
    if v_rls is distinct from true then
      raise exception 'FAIL: public.% missing RLS enabled', t;
    end if;
  end loop;

  select c.reloptions::text into v_invoker
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'product_catalog';
  if v_invoker is null or position('security_invoker=true' in v_invoker) = 0 then
    raise exception 'FAIL: product_catalog missing security_invoker=true';
  end if;

  select c.reloptions::text into v_invoker
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'inventory_availability';
  if v_invoker is null or position('security_invoker=true' in v_invoker) = 0 then
    raise exception
      'FAIL: inventory_availability missing security_invoker=true';
  end if;

  raise notice 'OK: baseline RLS + security_invoker metadata';
end $$;

-- ---------------------------------------------------------------------------
-- Grant-layer: PUBLIC / anon / authenticated / service_role matrix
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
  foreach t in array app_objects loop
    foreach priv in array array['SELECT', 'INSERT', 'UPDATE', 'DELETE'] loop
      perform pg_temp.assert_table_priv('public', 'public', t, priv, false);
    end loop;
  end loop;

  perform pg_temp.assert_siud('anon', 'categories', true, false, false, false);
  perform pg_temp.assert_siud('anon', 'brands', true, false, false, false);
  perform pg_temp.assert_siud('anon', 'products', true, false, false, false);
  perform pg_temp.assert_siud('anon', 'product_images', true, false, false, false);
  perform pg_temp.assert_siud('anon', 'product_catalog', true, false, false, false);

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

  perform pg_temp.assert_table_priv(
    'anon', 'public', 'product_variants', 'INSERT', false
  );
  perform pg_temp.assert_table_priv(
    'anon', 'public', 'product_variants', 'UPDATE', false
  );
  perform pg_temp.assert_table_priv(
    'anon', 'public', 'product_variants', 'DELETE', false
  );

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
  perform pg_temp.assert_siud(
    'authenticated', 'favorites', true, true, false, true
  );
  perform pg_temp.assert_siud(
    'authenticated', 'carts', true, true, true, true
  );
  perform pg_temp.assert_siud(
    'authenticated', 'cart_items', true, true, true, true
  );
  perform pg_temp.assert_siud(
    'authenticated', 'orders', true, true, true, false
  );
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

  -- Notifications: table SELECT; column UPDATE(is_read) only — not table-wide
  -- UPDATE. Do not use assert_siud for UPDATE (column grants make
  -- has_table_privilege('UPDATE') true).
  perform pg_temp.assert_table_priv(
    'authenticated', 'public', 'notifications', 'SELECT', true
  );
  perform pg_temp.assert_table_priv(
    'authenticated', 'public', 'notifications', 'INSERT', false
  );
  perform pg_temp.assert_table_priv(
    'authenticated', 'public', 'notifications', 'DELETE', false
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

  perform pg_temp.assert_table_priv(
    'authenticated', 'public', 'product_variants', 'INSERT', true
  );
  perform pg_temp.assert_table_priv(
    'authenticated', 'public', 'product_variants', 'UPDATE', true
  );
  perform pg_temp.assert_table_priv(
    'authenticated', 'public', 'product_variants', 'DELETE', true
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

  foreach t in array app_objects loop
    perform pg_temp.assert_siud('service_role', t, true, true, true, true);
  end loop;

  if not has_column_privilege(
    'service_role', 'public.product_variants', 'cost_price', 'SELECT'
  ) then
    raise exception
      'FAIL: service_role lost SELECT on product_variants.cost_price';
  end if;

  -- Storage: table grants exist for Data API roles; RLS enforces bucket rules.
  perform pg_temp.assert_table_priv(
    'anon', 'storage', 'objects', 'SELECT', true
  );
  perform pg_temp.assert_table_priv(
    'authenticated', 'storage', 'objects', 'SELECT', true
  );
  perform pg_temp.assert_table_priv(
    'authenticated', 'storage', 'objects', 'INSERT', true
  );
  perform pg_temp.assert_table_priv(
    'authenticated', 'storage', 'objects', 'UPDATE', true
  );
  perform pg_temp.assert_table_priv(
    'authenticated', 'storage', 'objects', 'DELETE', true
  );

  raise notice 'OK: grant-layer table/column/storage privileges';
end $$;

-- ---------------------------------------------------------------------------
-- Grant-layer: function EXECUTE contracts
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
  bad_cols text[] := array[
    'cost_price', 'quantity_reserved', 'reorder_level', 'quantity_on_hand'
  ];
  col text;
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

  foreach grantee in array array['anon', 'authenticated', 'service_role'] loop
    if not has_function_privilege(
      grantee, 'public.get_variant_availability(uuid)', 'EXECUTE'
    ) then
      raise exception
        'FAIL: % missing EXECUTE on get_variant_availability', grantee;
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

  if has_function_privilege(
    'public',
    'public.insert_cms_product_image(uuid, text, text, uuid, boolean)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: PUBLIC has EXECUTE on insert_cms_product_image';
  end if;
  if has_function_privilege(
    'anon',
    'public.insert_cms_product_image(uuid, text, text, uuid, boolean)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: anon has EXECUTE on insert_cms_product_image';
  end if;
  if not has_function_privilege(
    'authenticated',
    'public.insert_cms_product_image(uuid, text, text, uuid, boolean)',
    'EXECUTE'
  ) then
    raise exception
      'FAIL: authenticated missing EXECUTE on insert_cms_product_image';
  end if;
  if not has_function_privilege(
    'service_role',
    'public.insert_cms_product_image(uuid, text, text, uuid, boolean)',
    'EXECUTE'
  ) then
    raise exception
      'FAIL: service_role missing EXECUTE on insert_cms_product_image';
  end if;

  if has_function_privilege(
    'public',
    'public.update_cms_product_image(uuid, uuid, text, uuid, integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: PUBLIC has EXECUTE on update_cms_product_image';
  end if;
  if has_function_privilege(
    'anon',
    'public.update_cms_product_image(uuid, uuid, text, uuid, integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: anon has EXECUTE on update_cms_product_image';
  end if;
  if not has_function_privilege(
    'authenticated',
    'public.update_cms_product_image(uuid, uuid, text, uuid, integer)',
    'EXECUTE'
  ) then
    raise exception
      'FAIL: authenticated missing EXECUTE on update_cms_product_image';
  end if;
  if not has_function_privilege(
    'service_role',
    'public.update_cms_product_image(uuid, uuid, text, uuid, integer)',
    'EXECUTE'
  ) then
    raise exception
      'FAIL: service_role missing EXECUTE on update_cms_product_image';
  end if;

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

  -- Catalog RPC return columns must not expose protected inventory/cost fields.
  foreach col in array bad_cols loop
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'product_catalog'
        and column_name = col
    ) then
      raise exception 'FAIL: product_catalog exposes column %', col;
    end if;
  end loop;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join unnest(p.proargnames) with ordinality as args(argname, ord)
      on true
    where n.nspname = 'public'
      and p.proname = 'get_variant_availability'
      and args.argname = any (bad_cols)
  ) then
    raise exception
      'FAIL: get_variant_availability exposes a protected column name';
  end if;

  -- search_products returns setof product_catalog; assert its composite
  -- return attributes exclude protected cost/inventory fields explicitly.
  if (
    select t.typname
    from pg_proc p
    join pg_type t on t.oid = p.prorettype
    where p.oid = 'public.search_products(text, integer)'::regprocedure
  ) is distinct from 'product_catalog' then
    raise exception
      'FAIL: search_products return type is not product_catalog';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_type t on t.oid = p.prorettype
    join pg_attribute a on a.attrelid = t.typrelid
    where p.oid = 'public.search_products(text, integer)'::regprocedure
      and a.attnum > 0
      and not a.attisdropped
      and a.attname = any (bad_cols)
  ) then
    raise exception
      'FAIL: search_products exposes a protected column name';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join unnest(p.proargnames) as args(argname)
      on true
    where n.nspname = 'public'
      and p.proname = 'list_cms_products'
      and args.argname = any (
        bad_cols || array['barcode', 'email', 'user_id', 'phone_number']
      )
  ) then
    raise exception
      'FAIL: list_cms_products exposes a protected column name';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral unnest(p.proargnames, p.proargmodes)
      as args(argname, mode)
    where n.nspname = 'public'
      and p.proname = 'save_cms_product_variant'
      and args.mode = 't'
      and args.argname = any (
        bad_cols || array['barcode', 'email', 'user_id', 'phone_number']
      )
  ) then
    raise exception
      'FAIL: save_cms_product_variant returns a protected column name';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral unnest(p.proargnames, p.proargmodes)
      as args(argname, mode)
    where n.nspname = 'public'
      and p.proname in (
        'set_cms_product_image_primary',
        'reorder_cms_product_images',
        'insert_cms_product_image',
        'update_cms_product_image'
      )
      and args.mode = 't'
      and args.argname = any (
        bad_cols || array['barcode', 'email', 'user_id', 'phone_number', 'storage_path']
      )
  ) then
    raise exception
      'FAIL: product media RPC returns a protected column name';
  end if;

  raise notice 'OK: function EXECUTE + RPC schema contracts';
end $$;

-- ---------------------------------------------------------------------------
-- Deterministic fixtures (owner context; rolled back)
-- ---------------------------------------------------------------------------
select pg_temp.rls_insert_user(
  'a6000000-0000-4000-8000-000000000001',
  'rls-customer-a@example.invalid'
);
select pg_temp.rls_insert_user(
  'a6000000-0000-4000-8000-000000000002',
  'rls-customer-b@example.invalid'
);
select pg_temp.rls_insert_user(
  'a6000000-0000-4000-8000-000000000003',
  'rls-staff@example.invalid'
);
select pg_temp.rls_insert_user(
  'a6000000-0000-4000-8000-000000000004',
  'rls-admin@example.invalid'
);
select pg_temp.rls_insert_user(
  'a6000000-0000-4000-8000-000000000005',
  'rls-forged@example.invalid'
);

update public.profiles
set role = 'staff', full_name = 'RLS Staff'
where id = 'a6000000-0000-4000-8000-000000000003';

update public.profiles
set role = 'admin', full_name = 'RLS Admin'
where id = 'a6000000-0000-4000-8000-000000000004';

update public.profiles
set full_name = 'RLS Customer A'
where id = 'a6000000-0000-4000-8000-000000000001';

update public.profiles
set full_name = 'RLS Customer B'
where id = 'a6000000-0000-4000-8000-000000000002';

update public.profiles
set full_name = 'RLS Forged Customer'
where id = 'a6000000-0000-4000-8000-000000000005';

insert into public.categories (id, name, slug, sort_order, is_active) values
  (
    'a6100000-0000-4000-8000-000000000001',
    'RLS Active Category',
    'rls-active-category',
    910,
    true
  ),
  (
    'a6100000-0000-4000-8000-000000000002',
    'RLS Inactive Category',
    'rls-inactive-category',
    911,
    false
  );

insert into public.brands (id, name, slug, sort_order, is_active) values
  (
    'a6110000-0000-4000-8000-000000000001',
    'RLS Active Brand',
    'rls-active-brand',
    910,
    true
  ),
  (
    'a6110000-0000-4000-8000-000000000002',
    'RLS Inactive Brand',
    'rls-inactive-brand',
    911,
    false
  );

insert into public.products (
  id, category_id, brand_id, name, slug, status, is_featured, published_at
) values
  (
    'a6120000-0000-4000-8000-000000000001',
    'a6100000-0000-4000-8000-000000000001',
    'a6110000-0000-4000-8000-000000000001',
    'RLS Active Product',
    'rls-active-product',
    'active',
    false,
    timezone('utc', now())
  ),
  (
    'a6120000-0000-4000-8000-000000000002',
    'a6100000-0000-4000-8000-000000000001',
    'a6110000-0000-4000-8000-000000000001',
    'RLS Draft Product',
    'rls-draft-product',
    'draft',
    false,
    null
  );

insert into public.product_variants (
  id, product_id, sku, name, price, cost_price, is_active, is_default, sort_order
) values
  (
    'a6130000-0000-4000-8000-000000000001',
    'a6120000-0000-4000-8000-000000000001',
    'RLS-SKU-ACTIVE',
    'Active Variant',
    100000,
    50000,
    true,
    true,
    0
  ),
  (
    'a6130000-0000-4000-8000-000000000002',
    'a6120000-0000-4000-8000-000000000001',
    'RLS-SKU-INACTIVE',
    'Inactive Variant',
    100000,
    50000,
    false,
    false,
    1
  ),
  (
    'a6130000-0000-4000-8000-000000000003',
    'a6120000-0000-4000-8000-000000000002',
    'RLS-SKU-DRAFT',
    'Draft Product Variant',
    100000,
    50000,
    true,
    true,
    0
  );

insert into public.product_images (
  id, product_id, storage_path, is_primary, sort_order
) values
  (
    'a6140000-0000-4000-8000-000000000001',
    'a6120000-0000-4000-8000-000000000001',
    'product-images/rls-active.webp',
    true,
    0
  ),
  (
    'a6140000-0000-4000-8000-000000000002',
    'a6120000-0000-4000-8000-000000000002',
    'product-images/rls-draft.webp',
    true,
    0
  );

insert into public.inventory (
  variant_id, quantity_on_hand, quantity_reserved, reorder_level, allow_backorder
) values
  ('a6130000-0000-4000-8000-000000000001', 10, 1, 2, false),
  ('a6130000-0000-4000-8000-000000000002', 5, 0, 1, false),
  ('a6130000-0000-4000-8000-000000000003', 8, 0, 1, false);

insert into public.addresses (
  id, user_id, recipient_name, phone_number,
  province_name, district_name, ward_name, street_address, is_default
) values
  (
    'a6200000-0000-4000-8000-000000000001',
    'a6000000-0000-4000-8000-000000000001',
    'Customer A',
    '0906000001',
    'TP Hồ Chí Minh',
    'Quận 1',
    'Phường Bến Nghé',
    '6 RLS Street A',
    true
  ),
  (
    'a6200000-0000-4000-8000-000000000002',
    'a6000000-0000-4000-8000-000000000002',
    'Customer B',
    '0906000002',
    'Hà Nội',
    'Quận Ba Đình',
    'Phường Điện Biên',
    '6 RLS Street B',
    true
  );

insert into public.favorites (user_id, product_id) values
  (
    'a6000000-0000-4000-8000-000000000001',
    'a6120000-0000-4000-8000-000000000001'
  ),
  (
    'a6000000-0000-4000-8000-000000000002',
    'a6120000-0000-4000-8000-000000000001'
  );

insert into public.carts (id, user_id, status, currency_code) values
  (
    'a6600000-0000-4000-8000-000000000001',
    'a6000000-0000-4000-8000-000000000001',
    'active',
    'VND'
  ),
  (
    'a6600000-0000-4000-8000-000000000002',
    'a6000000-0000-4000-8000-000000000002',
    'active',
    'VND'
  );

insert into public.cart_items (
  id, cart_id, variant_id, quantity, unit_price_snapshot
) values
  (
    'a6700000-0000-4000-8000-000000000001',
    'a6600000-0000-4000-8000-000000000001',
    'a6130000-0000-4000-8000-000000000001',
    1,
    100000
  ),
  (
    'a6700000-0000-4000-8000-000000000002',
    'a6600000-0000-4000-8000-000000000002',
    'a6130000-0000-4000-8000-000000000001',
    1,
    100000
  );

insert into public.orders (
  id, order_number, user_id, status,
  subtotal, discount_total, shipping_fee, grand_total,
  recipient_name, recipient_phone, shipping_address, payment_status
) values
  (
    'a6300000-0000-4000-8000-000000000001',
    'BDM-RLS-A001',
    'a6000000-0000-4000-8000-000000000001',
    'pending',
    100000, 0, 0, 100000,
    'Customer A',
    '0906000001',
    '{"line1":"6 RLS Street A"}'::jsonb,
    'unpaid'
  ),
  (
    'a6300000-0000-4000-8000-000000000002',
    'BDM-RLS-B001',
    'a6000000-0000-4000-8000-000000000002',
    'pending',
    100000, 0, 0, 100000,
    'Customer B',
    '0906000002',
    '{"line1":"6 RLS Street B"}'::jsonb,
    'unpaid'
  );

insert into public.order_items (
  id, order_id, product_id, variant_id, product_name, variant_name, sku,
  unit_price, quantity, line_total
) values
  (
    'a6400000-0000-4000-8000-000000000001',
    'a6300000-0000-4000-8000-000000000001',
    'a6120000-0000-4000-8000-000000000001',
    'a6130000-0000-4000-8000-000000000001',
    'RLS Active Product',
    'Active Variant',
    'RLS-SKU-ACTIVE',
    100000, 1, 100000
  ),
  (
    'a6400000-0000-4000-8000-000000000002',
    'a6300000-0000-4000-8000-000000000002',
    'a6120000-0000-4000-8000-000000000001',
    'a6130000-0000-4000-8000-000000000001',
    'RLS Active Product',
    'Active Variant',
    'RLS-SKU-ACTIVE',
    100000, 1, 100000
  );

-- Storage fixtures (owner insert; non-sensitive metadata only).
insert into storage.objects (id, bucket_id, name, metadata) values
  (
    'a6900000-0000-4000-8000-000000000001',
    'product-images',
    'rls-task006/product.webp',
    '{"mimetype":"image/webp","size":16}'::jsonb
  ),
  (
    'a6900000-0000-4000-8000-000000000002',
    'brand-assets',
    'rls-task006/brand.webp',
    '{"mimetype":"image/webp","size":16}'::jsonb
  ),
  (
    'a6900000-0000-4000-8000-000000000003',
    'category-assets',
    'rls-task006/category.webp',
    '{"mimetype":"image/webp","size":16}'::jsonb
  ),
  (
    'a6900000-0000-4000-8000-000000000004',
    'user-avatars',
    'a6000000-0000-4000-8000-000000000001/avatar.webp',
    '{"mimetype":"image/webp","size":16}'::jsonb
  ),
  (
    'a6900000-0000-4000-8000-000000000005',
    'user-avatars',
    'a6000000-0000-4000-8000-000000000002/avatar.webp',
    '{"mimetype":"image/webp","size":16}'::jsonb
  ),
  (
    'a6900000-0000-4000-8000-000000000006',
    'product-images',
    'rls-task006/staff-target.webp',
    '{"mimetype":"image/webp","size":16}'::jsonb
  );

-- ---------------------------------------------------------------------------
-- 2. Anonymous catalog boundary
-- ---------------------------------------------------------------------------
do $$
declare
  v_count integer;
begin
  perform pg_temp.rls_set_anon();

  perform pg_temp.assert_count(
    'anon active category',
    $q$select count(*)::integer from public.categories
       where id = 'a6100000-0000-4000-8000-000000000001'$q$,
    1
  );
  perform pg_temp.assert_count(
    'anon inactive category',
    $q$select count(*)::integer from public.categories
       where id = 'a6100000-0000-4000-8000-000000000002'$q$,
    0
  );
  perform pg_temp.assert_count(
    'anon active brand',
    $q$select count(*)::integer from public.brands
       where id = 'a6110000-0000-4000-8000-000000000001'$q$,
    1
  );
  perform pg_temp.assert_count(
    'anon inactive brand',
    $q$select count(*)::integer from public.brands
       where id = 'a6110000-0000-4000-8000-000000000002'$q$,
    0
  );
  perform pg_temp.assert_count(
    'anon active product',
    $q$select count(*)::integer from public.products
       where id = 'a6120000-0000-4000-8000-000000000001'$q$,
    1
  );
  perform pg_temp.assert_count(
    'anon draft product',
    $q$select count(*)::integer from public.products
       where id = 'a6120000-0000-4000-8000-000000000002'$q$,
    0
  );
  perform pg_temp.assert_count(
    'anon active variant',
    $q$select count(*)::integer from public.product_variants
       where id = 'a6130000-0000-4000-8000-000000000001'$q$,
    1
  );
  perform pg_temp.assert_count(
    'anon inactive variant',
    $q$select count(*)::integer from public.product_variants
       where id = 'a6130000-0000-4000-8000-000000000002'$q$,
    0
  );
  perform pg_temp.assert_count(
    'anon draft-product variant',
    $q$select count(*)::integer from public.product_variants
       where id = 'a6130000-0000-4000-8000-000000000003'$q$,
    0
  );
  perform pg_temp.assert_count(
    'anon active product image',
    $q$select count(*)::integer from public.product_images
       where id = 'a6140000-0000-4000-8000-000000000001'$q$,
    1
  );
  perform pg_temp.assert_count(
    'anon draft product image',
    $q$select count(*)::integer from public.product_images
       where id = 'a6140000-0000-4000-8000-000000000002'$q$,
    0
  );
  perform pg_temp.assert_count(
    'anon product_catalog active',
    $q$select count(*)::integer from public.product_catalog
       where id = 'a6120000-0000-4000-8000-000000000001'$q$,
    1
  );
  perform pg_temp.assert_count(
    'anon product_catalog draft',
    $q$select count(*)::integer from public.product_catalog
       where id = 'a6120000-0000-4000-8000-000000000002'$q$,
    0
  );

  -- Catalog writes denied at grant layer.
  perform pg_temp.assert_privilege_error(
    'anon category INSERT',
    $q$insert into public.categories (name, slug, sort_order)
       values ('Anon Write', 'anon-rls-write', 1)$q$
  );
  perform pg_temp.assert_privilege_error(
    'anon profiles SELECT',
    $q$select count(*) from public.profiles$q$
  );
  perform pg_temp.assert_privilege_error(
    'anon addresses SELECT',
    $q$select count(*) from public.addresses$q$
  );
  perform pg_temp.assert_privilege_error(
    'anon favorites SELECT',
    $q$select count(*) from public.favorites$q$
  );
  perform pg_temp.assert_privilege_error(
    'anon carts SELECT',
    $q$select count(*) from public.carts$q$
  );
  perform pg_temp.assert_privilege_error(
    'anon orders SELECT',
    $q$select count(*) from public.orders$q$
  );
  perform pg_temp.assert_privilege_error(
    'anon inventory SELECT',
    $q$select count(*) from public.inventory$q$
  );
  perform pg_temp.assert_privilege_error(
    'anon inventory_availability SELECT',
    $q$select count(*) from public.inventory_availability$q$
  );

  -- Safe public RPC (no protected columns in result).
  select count(*) into v_count
  from public.get_variant_availability(
    'a6130000-0000-4000-8000-000000000001'
  );
  if v_count <> 1 then
    raise exception
      'FAIL: anon get_variant_availability count=%', v_count;
  end if;

  perform pg_temp.rls_clear_auth();
  raise notice 'OK: anon catalog boundary + grant denials';
exception
  when others then
    perform pg_temp.rls_clear_auth();
    raise;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Customer A vs Customer B isolation
-- ---------------------------------------------------------------------------
do $$
declare
  v_a uuid := 'a6000000-0000-4000-8000-000000000001';
  v_b uuid := 'a6000000-0000-4000-8000-000000000002';
  v_addr_a uuid := 'a6200000-0000-4000-8000-000000000001';
  v_addr_b uuid := 'a6200000-0000-4000-8000-000000000002';
  v_cart_a uuid := 'a6600000-0000-4000-8000-000000000001';
  v_cart_b uuid := 'a6600000-0000-4000-8000-000000000002';
  v_item_a uuid := 'a6700000-0000-4000-8000-000000000001';
  v_item_b uuid := 'a6700000-0000-4000-8000-000000000002';
  v_order_a uuid := 'a6300000-0000-4000-8000-000000000001';
  v_order_b uuid := 'a6300000-0000-4000-8000-000000000002';
  v_product uuid := 'a6120000-0000-4000-8000-000000000001';
  v_draft_product uuid := 'a6120000-0000-4000-8000-000000000002';
  v_inactive_variant uuid := 'a6130000-0000-4000-8000-000000000002';
  v_new_addr_a uuid := 'a6200000-0000-4000-8000-000000000011';
  v_new_addr_b uuid := 'a6200000-0000-4000-8000-000000000012';
  v_cart_extra_a uuid := 'a6600000-0000-4000-8000-000000000011';
  v_cart_extra_b uuid := 'a6600000-0000-4000-8000-000000000012';
  v_item_extra_a uuid := 'a6700000-0000-4000-8000-000000000011';
  v_item_extra_b uuid := 'a6700000-0000-4000-8000-000000000012';
  v_count integer;
  v_qty integer;
  v_street text;
  v_name text;
begin
  -- ----- Customer A: full owned CRUD on required surfaces -----
  perform pg_temp.rls_set_auth(v_a);

  select full_name into v_name from public.profiles where id = v_a;
  if v_name is distinct from 'RLS Customer A' then
    raise exception 'FAIL: customer A cannot read own profile';
  end if;

  update public.profiles
  set full_name = 'RLS Customer A Updated', phone_number = '0906111111'
  where id = v_a;
  if not found then
    raise exception 'FAIL: customer A cannot UPDATE own profile fields';
  end if;

  select count(*) into v_count from public.addresses where id = v_addr_a;
  if v_count <> 1 then
    raise exception 'FAIL: customer A cannot SELECT own address';
  end if;

  update public.addresses
  set street_address = '6 RLS Street A Updated'
  where id = v_addr_a;
  if not found then
    raise exception 'FAIL: customer A cannot UPDATE own address';
  end if;

  insert into public.addresses (
    id, user_id, recipient_name, phone_number,
    province_name, district_name, ward_name, street_address, is_default
  ) values (
    v_new_addr_a, v_a, 'Customer A2', '0906000011',
    'TP Hồ Chí Minh', 'Quận 1', 'Phường Bến Nghé', '6 RLS Extra A', false
  );

  delete from public.addresses where id = v_new_addr_a;
  if not found then
    raise exception 'FAIL: customer A cannot DELETE own address';
  end if;

  select count(*) into v_count
  from public.favorites
  where user_id = v_a and product_id = v_product;
  if v_count <> 1 then
    raise exception 'FAIL: customer A cannot SELECT own favorite';
  end if;

  insert into public.favorites (user_id, product_id)
  values (v_a, v_draft_product);

  delete from public.favorites
  where user_id = v_a and product_id = v_draft_product;
  if not found then
    raise exception 'FAIL: customer A cannot DELETE own favorite';
  end if;

  select count(*) into v_count from public.carts where id = v_cart_a;
  if v_count <> 1 then
    raise exception 'FAIL: customer A cannot SELECT own cart';
  end if;

  update public.carts
  set expires_at = timezone('utc', now()) + interval '7 days'
  where id = v_cart_a;
  if not found then
    raise exception 'FAIL: customer A cannot UPDATE own cart';
  end if;

  -- Extra abandoned cart avoids carts_one_active_per_user_idx.
  insert into public.carts (id, user_id, status, currency_code)
  values (v_cart_extra_a, v_a, 'abandoned', 'VND');

  delete from public.carts where id = v_cart_extra_a;
  if not found then
    raise exception 'FAIL: customer A cannot DELETE own cart';
  end if;

  select count(*) into v_count from public.cart_items where id = v_item_a;
  if v_count <> 1 then
    raise exception 'FAIL: customer A cannot SELECT own cart_item';
  end if;

  update public.cart_items set quantity = 2 where id = v_item_a;
  if not found then
    raise exception 'FAIL: customer A cannot UPDATE own cart_item';
  end if;

  insert into public.cart_items (
    id, cart_id, variant_id, quantity, unit_price_snapshot
  ) values (
    v_item_extra_a, v_cart_a, v_inactive_variant, 1, 100000
  );

  delete from public.cart_items where id = v_item_extra_a;
  if not found then
    raise exception 'FAIL: customer A cannot DELETE own cart_item';
  end if;

  select count(*) into v_count from public.orders where id = v_order_a;
  if v_count <> 1 then
    raise exception 'FAIL: customer A cannot SELECT own order';
  end if;
  select count(*) into v_count
  from public.order_items where order_id = v_order_a;
  if v_count <> 1 then
    raise exception 'FAIL: customer A cannot SELECT own order_items';
  end if;
  select count(*) into v_count
  from public.order_status_history where order_id = v_order_a;
  if v_count < 1 then
    raise exception 'FAIL: customer A cannot SELECT own order history';
  end if;

  -- Cross-user invisibility from A.
  select count(*) into v_count from public.addresses where id = v_addr_b;
  if v_count <> 0 then
    raise exception 'FAIL: customer A can see B address';
  end if;
  select count(*) into v_count from public.orders where id = v_order_b;
  if v_count <> 0 then
    raise exception 'FAIL: customer A can see B order';
  end if;
  select count(*) into v_count from public.profiles where id = v_b;
  if v_count <> 0 then
    raise exception 'FAIL: customer A can see B profile';
  end if;

  perform pg_temp.rls_clear_auth();

  -- ----- Customer B: full owned CRUD on required surfaces -----
  perform pg_temp.rls_set_auth(v_b);

  select full_name into v_name from public.profiles where id = v_b;
  if v_name is distinct from 'RLS Customer B' then
    raise exception 'FAIL: customer B cannot read own profile';
  end if;

  update public.profiles
  set full_name = 'RLS Customer B Updated', phone_number = '0906222222'
  where id = v_b;
  if not found then
    raise exception 'FAIL: customer B cannot UPDATE own profile fields';
  end if;

  select count(*) into v_count from public.addresses where id = v_addr_b;
  if v_count <> 1 then
    raise exception 'FAIL: customer B cannot SELECT own address';
  end if;

  update public.addresses
  set street_address = '6 RLS Street B Updated'
  where id = v_addr_b;
  if not found then
    raise exception 'FAIL: customer B cannot UPDATE own address';
  end if;

  insert into public.addresses (
    id, user_id, recipient_name, phone_number,
    province_name, district_name, ward_name, street_address, is_default
  ) values (
    v_new_addr_b, v_b, 'Customer B2', '0906000022',
    'Hà Nội', 'Quận Ba Đình', 'Phường Điện Biên', '6 RLS Extra B', false
  );

  delete from public.addresses where id = v_new_addr_b;
  if not found then
    raise exception 'FAIL: customer B cannot DELETE own address';
  end if;

  select count(*) into v_count
  from public.favorites
  where user_id = v_b and product_id = v_product;
  if v_count <> 1 then
    raise exception 'FAIL: customer B cannot SELECT own favorite';
  end if;

  insert into public.favorites (user_id, product_id)
  values (v_b, v_draft_product);

  delete from public.favorites
  where user_id = v_b and product_id = v_draft_product;
  if not found then
    raise exception 'FAIL: customer B cannot DELETE own favorite';
  end if;

  select count(*) into v_count from public.carts where id = v_cart_b;
  if v_count <> 1 then
    raise exception 'FAIL: customer B cannot SELECT own cart';
  end if;

  update public.carts
  set expires_at = timezone('utc', now()) + interval '7 days'
  where id = v_cart_b;
  if not found then
    raise exception 'FAIL: customer B cannot UPDATE own cart';
  end if;

  insert into public.carts (id, user_id, status, currency_code)
  values (v_cart_extra_b, v_b, 'abandoned', 'VND');

  delete from public.carts where id = v_cart_extra_b;
  if not found then
    raise exception 'FAIL: customer B cannot DELETE own cart';
  end if;

  select count(*) into v_count from public.cart_items where id = v_item_b;
  if v_count <> 1 then
    raise exception 'FAIL: customer B cannot SELECT own cart_item';
  end if;

  update public.cart_items set quantity = 3 where id = v_item_b;
  if not found then
    raise exception 'FAIL: customer B cannot UPDATE own cart_item';
  end if;

  insert into public.cart_items (
    id, cart_id, variant_id, quantity, unit_price_snapshot
  ) values (
    v_item_extra_b, v_cart_b, v_inactive_variant, 1, 100000
  );

  delete from public.cart_items where id = v_item_extra_b;
  if not found then
    raise exception 'FAIL: customer B cannot DELETE own cart_item';
  end if;

  select count(*) into v_count from public.orders where id = v_order_b;
  if v_count <> 1 then
    raise exception 'FAIL: customer B cannot SELECT own order';
  end if;

  -- Favorites have no UPDATE grant; deny at grant layer for B.
  perform pg_temp.assert_privilege_error(
    'B favorite UPDATE',
    format(
      $q$update public.favorites set created_at = timezone('utc', now())
         where user_id = %L and product_id = %L$q$,
      v_b, v_product
    )
  );

  perform pg_temp.rls_clear_auth();

  select quantity into v_qty from public.cart_items where id = v_item_a;
  select street_address into v_street from public.addresses where id = v_addr_a;

  -- Customer B attacks A.
  perform pg_temp.rls_set_auth(v_b);

  select count(*) into v_count from public.addresses where id = v_addr_a;
  if v_count <> 0 then
    raise exception 'FAIL: customer B can SELECT A address';
  end if;
  select count(*) into v_count from public.carts where id = v_cart_a;
  if v_count <> 0 then
    raise exception 'FAIL: customer B can SELECT A cart';
  end if;
  select count(*) into v_count from public.orders where id = v_order_a;
  if v_count <> 0 then
    raise exception 'FAIL: customer B can SELECT A order';
  end if;
  select count(*) into v_count
  from public.order_items where order_id = v_order_a;
  if v_count <> 0 then
    raise exception 'FAIL: customer B can SELECT A order_items';
  end if;
  select count(*) into v_count
  from public.order_status_history where order_id = v_order_a;
  if v_count <> 0 then
    raise exception 'FAIL: customer B can SELECT A order history';
  end if;
  select count(*) into v_count
  from public.favorites where user_id = v_a and product_id = v_product;
  if v_count <> 0 then
    raise exception 'FAIL: customer B can SELECT A favorite';
  end if;

  perform pg_temp.assert_denied_or_zero(
    'B update A address',
    format(
      $q$update public.addresses set street_address = 'hacked' where id = %L$q$,
      v_addr_a
    )
  );
  perform pg_temp.assert_denied_or_zero(
    'B delete A favorite',
    format(
      $q$delete from public.favorites
         where user_id = %L and product_id = %L$q$,
      v_a, v_product
    )
  );
  perform pg_temp.assert_denied_or_zero(
    'B update A cart',
    format(
      $q$update public.carts set status = 'abandoned' where id = %L$q$,
      v_cart_a
    )
  );
  perform pg_temp.assert_denied_or_zero(
    'B update A cart_item',
    format(
      $q$update public.cart_items set quantity = 99 where id = %L$q$,
      v_item_a
    )
  );
  perform pg_temp.assert_denied_or_zero(
    'B delete A cart_item',
    format($q$delete from public.cart_items where id = %L$q$, v_item_a)
  );
  -- Parent cart is invisible under B's RLS, so the active-cart trigger raises
  -- P0002 before WITH CHECK; treat that as the documented denial here.
  perform pg_temp.assert_denied_or_zero(
    'B insert into A cart',
    format(
      $q$insert into public.cart_items (cart_id, variant_id, quantity)
         values (%L, 'a6130000-0000-4000-8000-000000000001', 1)$q$,
      v_cart_a
    ),
    true,
    array['P0002']
  );
  perform pg_temp.assert_denied_or_zero(
    'B insert address as A',
    format(
      $q$insert into public.addresses (
           user_id, recipient_name, phone_number,
           province_name, district_name, ward_name, street_address
         ) values (
           %L, 'Hijack', '0906000099',
           'X', 'Y', 'Z', 'hijack'
         )$q$,
      v_a
    )
  );

  perform pg_temp.rls_clear_auth();

  if (
    select street_address from public.addresses where id = v_addr_a
  ) is distinct from v_street then
    raise exception 'FAIL: A address mutated by B';
  end if;
  if (
    select quantity from public.cart_items where id = v_item_a
  ) is distinct from v_qty then
    raise exception 'FAIL: A cart_item mutated by B';
  end if;
  if (
    select count(*) from public.favorites
    where user_id = v_a and product_id = v_product
  ) <> 1 then
    raise exception 'FAIL: A favorite mutated by B';
  end if;
  if (
    select status from public.carts where id = v_cart_a
  ) is distinct from 'active' then
    raise exception 'FAIL: A cart mutated by B';
  end if;

  raise notice 'OK: customer A/B isolation + owned CRUD';
exception
  when others then
    perform pg_temp.rls_clear_auth();
    raise;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Direct commerce boundary (customer cannot write privileged surfaces)
-- ---------------------------------------------------------------------------
do $$
declare
  v_a uuid := 'a6000000-0000-4000-8000-000000000001';
  v_order_a uuid := 'a6300000-0000-4000-8000-000000000001';
  v_product uuid := 'a6120000-0000-4000-8000-000000000001';
  v_variant uuid := 'a6130000-0000-4000-8000-000000000001';
  v_reserved integer;
  v_item_count integer;
  v_history_count integer;
  v_status text;
  v_subtotal numeric;
  v_payment text;
  v_inv_count integer;
begin
  select quantity_reserved into v_reserved
  from public.inventory where variant_id = v_variant;
  select count(*) into v_item_count
  from public.order_items where order_id = v_order_a;
  select count(*) into v_history_count
  from public.order_status_history where order_id = v_order_a;
  select status, subtotal, payment_status
  into v_status, v_subtotal, v_payment
  from public.orders where id = v_order_a;

  perform pg_temp.rls_set_auth(v_a);

  -- Inventory: grant exists; RLS must yield zero rows for customers.
  select count(*) into v_inv_count from public.inventory;
  if v_inv_count <> 0 then
    raise exception
      'FAIL: customer can SELECT raw inventory (count=%)', v_inv_count;
  end if;

  perform pg_temp.assert_denied_or_zero(
    'customer order INSERT',
    format(
      $q$insert into public.orders (
           order_number, user_id, subtotal, discount_total, shipping_fee,
           grand_total, recipient_name, recipient_phone, shipping_address
         ) values (
           'BDM-RLS-DIRECT', %L, 50, 0, 0, 50,
           'A', '0906000001', '{}'::jsonb
         )$q$,
      v_a
    )
  );
  perform pg_temp.assert_denied_or_zero(
    'customer order_items INSERT',
    format(
      $q$insert into public.order_items (
           order_id, product_id, variant_id, product_name, variant_name, sku,
           unit_price, quantity, line_total
         ) values (
           %L, %L, %L, 'X', 'Y', 'RLS-DIRECT', 50, 1, 50
         )$q$,
      v_order_a, v_product, v_variant
    )
  );
  perform pg_temp.assert_denied_or_zero(
    'customer order_status_history INSERT',
    format(
      $q$insert into public.order_status_history (
           order_id, from_status, to_status, note
         ) values (%L, 'pending', 'cancelled', 'customer')$q$,
      v_order_a
    )
  );
  perform pg_temp.assert_denied_or_zero(
    'customer order UPDATE',
    format(
      $q$update public.orders
         set status = 'cancelled', subtotal = 1, grand_total = 1,
             payment_status = 'paid', user_id = %L
         where id = %L$q$,
      'a6000000-0000-4000-8000-000000000002', v_order_a
    )
  );
  perform pg_temp.assert_denied_or_zero(
    'customer inventory UPDATE',
    format(
      $q$update public.inventory
         set quantity_reserved = quantity_reserved + 1
         where variant_id = %L$q$,
      v_variant
    )
  );
  perform pg_temp.assert_denied_or_zero(
    'customer inventory INSERT',
    $q$insert into public.inventory (variant_id, quantity_on_hand)
       values ('a6130000-0000-4000-8000-000000000099', 1)$q$
  );

  perform pg_temp.rls_clear_auth();

  if (
    select quantity_reserved from public.inventory where variant_id = v_variant
  ) is distinct from v_reserved then
    raise exception 'FAIL: inventory mutated by customer';
  end if;
  if (
    select count(*) from public.order_items where order_id = v_order_a
  ) is distinct from v_item_count then
    raise exception 'FAIL: order_items mutated by customer';
  end if;
  if (
    select count(*) from public.order_status_history where order_id = v_order_a
  ) is distinct from v_history_count then
    raise exception 'FAIL: order history mutated by customer';
  end if;
  if (
    select status from public.orders where id = v_order_a
  ) is distinct from v_status
     or (
       select subtotal from public.orders where id = v_order_a
     ) is distinct from v_subtotal
     or (
       select payment_status from public.orders where id = v_order_a
     ) is distinct from v_payment then
    raise exception 'FAIL: order privileged fields mutated by customer';
  end if;

  raise notice 'OK: customer commerce write boundary';
exception
  when others then
    perform pg_temp.rls_clear_auth();
    raise;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Privilege escalation protection
-- ---------------------------------------------------------------------------
do $$
declare
  v_a uuid := 'a6000000-0000-4000-8000-000000000001';
  v_b uuid := 'a6000000-0000-4000-8000-000000000002';
  v_forged uuid := 'a6000000-0000-4000-8000-000000000005';
  v_role text;
  v_active boolean;
  v_name text;
  v_staff boolean;
  v_admin boolean;
begin
  perform pg_temp.rls_set_auth(v_a);

  update public.profiles
  set
    full_name = 'RLS Customer A Safe',
    role = 'admin',
    is_active = false
  where id = v_a;
  if not found then
    raise exception 'FAIL: customer A self-update did not match own row';
  end if;

  perform pg_temp.assert_denied_or_zero(
    'A update B profile',
    format(
      $q$update public.profiles set full_name = 'hijack' where id = %L$q$,
      v_b
    )
  );

  perform pg_temp.rls_clear_auth();

  select role, is_active, full_name
  into v_role, v_active, v_name
  from public.profiles where id = v_a;

  if v_role is distinct from 'customer' then
    raise exception 'FAIL: customer escalated profiles.role';
  end if;
  if v_active is distinct from true then
    raise exception 'FAIL: customer changed profiles.is_active';
  end if;
  if v_name is distinct from 'RLS Customer A Safe' then
    raise exception 'FAIL: benign profile field did not update';
  end if;

  -- Forged JWT metadata with trusted customer profile.
  perform pg_temp.rls_set_auth_forged_staff(v_forged);

  select public.is_staff_or_admin() into v_staff;
  select public.is_admin() into v_admin;
  if v_staff or v_admin then
    raise exception
      'FAIL: forged JWT made is_staff_or_admin/is_admin true';
  end if;

  perform pg_temp.assert_denied_or_zero(
    'forged catalog INSERT',
    $q$insert into public.categories (name, slug, sort_order)
       values ('Forged Cat', 'rls-forged-cat', 1)$q$
  );
  perform pg_temp.assert_denied_or_zero(
    'forged inventory UPDATE',
    $q$update public.inventory
       set quantity_on_hand = quantity_on_hand + 1
       where variant_id = 'a6130000-0000-4000-8000-000000000001'$q$
  );
  perform pg_temp.assert_denied_or_zero(
    'forged order UPDATE',
    $q$update public.orders set status = 'cancelled'
       where id = 'a6300000-0000-4000-8000-000000000001'$q$
  );
  perform pg_temp.assert_denied_or_zero(
    'forged storage catalog INSERT',
    $q$insert into storage.objects (bucket_id, name)
       values ('product-images', 'rls-task006/forged.webp')$q$
  );

  perform pg_temp.rls_clear_auth();
  raise notice 'OK: privilege escalation + forged JWT denial';
exception
  when others then
    perform pg_temp.rls_clear_auth();
    raise;
end $$;

-- ---------------------------------------------------------------------------
-- 6. Staff / admin matrix (deployed is_staff_or_admin equivalence)
-- ---------------------------------------------------------------------------
do $$
declare
  v_staff uuid := 'a6000000-0000-4000-8000-000000000003';
  v_admin uuid := 'a6000000-0000-4000-8000-000000000004';
  v_customer_a uuid := 'a6000000-0000-4000-8000-000000000001';
  v_order_a uuid := 'a6300000-0000-4000-8000-000000000001';
  v_cat_id uuid := 'a6100000-0000-4000-8000-000000000011';
  v_staff_cat_delete uuid := 'a6100000-0000-4000-8000-000000000013';
  v_admin_cat uuid := 'a6100000-0000-4000-8000-000000000012';
  v_staff_brand uuid := 'a6110000-0000-4000-8000-000000000011';
  v_staff_product uuid := 'a6120000-0000-4000-8000-000000000011';
  v_staff_variant uuid := 'a6130000-0000-4000-8000-000000000011';
  v_staff_image uuid := 'a6140000-0000-4000-8000-000000000011';
  v_admin_brand uuid := 'a6110000-0000-4000-8000-000000000012';
  v_admin_product uuid := 'a6120000-0000-4000-8000-000000000012';
  v_admin_variant uuid := 'a6130000-0000-4000-8000-000000000012';
  v_admin_image uuid := 'a6140000-0000-4000-8000-000000000012';
  v_staff_order uuid := 'a6300000-0000-4000-8000-000000000011';
  v_history_id uuid := 'a6500000-0000-4000-8000-000000000001';
  v_count integer;
  v_on_hand integer;
  v_is_staff boolean;
  v_is_admin boolean;
  v_status text;
begin
  perform pg_temp.rls_set_auth(v_staff);
  select public.is_staff_or_admin() into v_is_staff;
  select public.is_admin() into v_is_admin;
  if not v_is_staff then
    raise exception 'FAIL: staff is_staff_or_admin() is false';
  end if;
  if v_is_admin then
    raise exception 'FAIL: staff is_admin() unexpectedly true';
  end if;

  perform pg_temp.assert_count(
    'staff inactive category',
    $q$select count(*)::integer from public.categories
       where id = 'a6100000-0000-4000-8000-000000000002'$q$,
    1
  );
  perform pg_temp.assert_count(
    'staff draft product',
    $q$select count(*)::integer from public.products
       where id = 'a6120000-0000-4000-8000-000000000002'$q$,
    1
  );
  perform pg_temp.assert_count(
    'staff inventory',
    $q$select count(*)::integer from public.inventory
       where variant_id = 'a6130000-0000-4000-8000-000000000001'$q$,
    1
  );
  perform pg_temp.assert_count(
    'staff all profiles',
    format(
      $q$select count(*)::integer from public.profiles
         where id in (%L, %L)$q$,
      v_customer_a, v_staff
    ),
    2
  );
  perform pg_temp.assert_count(
    'staff customer address',
    $q$select count(*)::integer from public.addresses
       where id = 'a6200000-0000-4000-8000-000000000001'$q$,
    1
  );
  perform pg_temp.assert_count(
    'staff customer cart',
    $q$select count(*)::integer from public.carts
       where id = 'a6600000-0000-4000-8000-000000000001'$q$,
    1
  );
  perform pg_temp.assert_count(
    'staff customer order',
    format(
      $q$select count(*)::integer from public.orders where id = %L$q$,
      v_order_a
    ),
    1
  );

  -- Categories INSERT / UPDATE / DELETE (v_cat_id kept for admin DELETE).
  insert into public.categories (id, name, slug, sort_order, is_active)
  values (v_cat_id, 'RLS Staff Category', 'rls-staff-category', 912, true);

  update public.categories
  set description = 'staff-updated'
  where id = v_cat_id;
  if not found then
    raise exception 'FAIL: staff cannot UPDATE category';
  end if;

  insert into public.categories (id, name, slug, sort_order, is_active)
  values (
    v_staff_cat_delete,
    'RLS Staff Category Delete',
    'rls-staff-category-delete',
    914,
    true
  );

  delete from public.categories where id = v_staff_cat_delete;
  if not found then
    raise exception 'FAIL: staff cannot DELETE category';
  end if;

  -- Brands INSERT / UPDATE / DELETE
  insert into public.brands (id, name, slug, sort_order, is_active)
  values (v_staff_brand, 'RLS Staff Brand', 'rls-staff-brand', 920, true);

  update public.brands
  set description = 'staff-brand-updated'
  where id = v_staff_brand;
  if not found then
    raise exception 'FAIL: staff cannot UPDATE brand';
  end if;

  -- Products INSERT / UPDATE under existing active category + staff brand
  insert into public.products (
    id, category_id, brand_id, name, slug, status, is_featured, published_at
  ) values (
    v_staff_product,
    'a6100000-0000-4000-8000-000000000001',
    v_staff_brand,
    'RLS Staff Product',
    'rls-staff-product',
    'draft',
    false,
    null
  );

  update public.products
  set short_description = 'staff-product-updated'
  where id = v_staff_product;
  if not found then
    raise exception 'FAIL: staff cannot UPDATE product';
  end if;

  -- Variants INSERT / UPDATE (omit cost_price; authenticated has no SELECT)
  insert into public.product_variants (
    id, product_id, sku, name, price, is_active, is_default, sort_order
  ) values (
    v_staff_variant,
    v_staff_product,
    'RLS-SKU-STAFF',
    'Staff Variant',
    150000,
    true,
    true,
    0
  );

  update public.product_variants
  set name = 'Staff Variant Updated'
  where id = v_staff_variant;
  if not found then
    raise exception 'FAIL: staff cannot UPDATE variant';
  end if;

  -- Images INSERT / UPDATE / DELETE (non-primary avoids unique primary clash)
  insert into public.product_images (
    id, product_id, storage_path, is_primary, sort_order, alt_text
  ) values (
    v_staff_image,
    v_staff_product,
    'product-images/rls-staff.webp',
    false,
    1,
    'staff-image'
  );

  update public.product_images
  set alt_text = 'staff-image-updated'
  where id = v_staff_image;
  if not found then
    raise exception 'FAIL: staff cannot UPDATE product_image';
  end if;

  -- Inventory INSERT / UPDATE / DELETE for the staff-created variant
  insert into public.inventory (
    variant_id, quantity_on_hand, quantity_reserved, reorder_level, allow_backorder
  ) values (
    v_staff_variant, 4, 0, 1, false
  );

  update public.inventory
  set quantity_on_hand = quantity_on_hand + 1
  where variant_id = v_staff_variant;
  if not found then
    raise exception 'FAIL: staff cannot UPDATE staff inventory row';
  end if;

  delete from public.inventory where variant_id = v_staff_variant;
  if not found then
    raise exception 'FAIL: staff cannot DELETE inventory';
  end if;

  insert into public.inventory (
    variant_id, quantity_on_hand, quantity_reserved, reorder_level, allow_backorder
  ) values (
    v_staff_variant, 4, 0, 1, false
  );

  delete from public.product_images where id = v_staff_image;
  if not found then
    raise exception 'FAIL: staff cannot DELETE product_image';
  end if;

  delete from public.product_variants where id = v_staff_variant;
  if not found then
    raise exception 'FAIL: staff cannot DELETE variant';
  end if;

  delete from public.products where id = v_staff_product;
  if not found then
    raise exception 'FAIL: staff cannot DELETE product';
  end if;

  delete from public.brands where id = v_staff_brand;
  if not found then
    raise exception 'FAIL: staff cannot DELETE brand';
  end if;

  -- Existing fixture inventory UPDATE (persisted for owner check below)
  select quantity_on_hand into v_on_hand
  from public.inventory
  where variant_id = 'a6130000-0000-4000-8000-000000000001';

  update public.inventory
  set quantity_on_hand = quantity_on_hand + 1
  where variant_id = 'a6130000-0000-4000-8000-000000000001';
  if not found then
    raise exception 'FAIL: staff cannot UPDATE inventory';
  end if;

  -- Orders / order_items / history: granted INSERT/UPDATE (no DELETE grant)
  insert into public.orders (
    id, order_number, user_id,
    subtotal, discount_total, shipping_fee, grand_total,
    recipient_name, recipient_phone, shipping_address
  ) values (
    v_staff_order,
    'BDM-RLS-STAFF1',
    v_customer_a,
    200000, 0, 0, 200000,
    'Staff Created',
    '0906000090',
    '{"line1":"staff"}'::jsonb
  );

  insert into public.order_items (
    order_id, product_id, variant_id, product_name, variant_name, sku,
    unit_price, quantity, line_total
  ) values (
    v_staff_order,
    'a6120000-0000-4000-8000-000000000001',
    'a6130000-0000-4000-8000-000000000001',
    'RLS Active Product',
    'Active Variant',
    'RLS-SKU-ACTIVE',
    200000, 1, 200000
  );

  select status into v_status from public.orders where id = v_order_a;
  update public.orders set status = 'confirmed' where id = v_order_a;
  if not found then
    raise exception 'FAIL: staff cannot UPDATE order status';
  end if;

  insert into public.order_status_history (
    id, order_id, from_status, to_status, changed_by, note
  ) values (
    v_history_id, v_order_a, v_status, 'confirmed', v_staff, 'staff-note'
  );

  -- Not granted: order DELETE / order_items UPDATE
  perform pg_temp.assert_privilege_error(
    'staff order DELETE',
    format($q$delete from public.orders where id = %L$q$, v_staff_order)
  );
  perform pg_temp.assert_privilege_error(
    'staff order_items UPDATE',
    format(
      $q$update public.order_items set quantity = 2 where order_id = %L$q$,
      v_staff_order
    )
  );

  perform pg_temp.rls_clear_auth();

  if (
    select quantity_on_hand
    from public.inventory
    where variant_id = 'a6130000-0000-4000-8000-000000000001'
  ) is distinct from v_on_hand + 1 then
    raise exception 'FAIL: staff inventory UPDATE did not persist';
  end if;

  if (
    select count(*) from public.brands where id = v_staff_brand
  ) <> 0 then
    raise exception 'FAIL: staff brand DELETE did not persist';
  end if;

  if (
    select count(*) from public.categories where id = v_staff_cat_delete
  ) <> 0 then
    raise exception 'FAIL: staff category DELETE did not persist';
  end if;

  -- Admin: same operational paths; is_admin() true.
  perform pg_temp.rls_set_auth(v_admin);
  select public.is_staff_or_admin() into v_is_staff;
  select public.is_admin() into v_is_admin;
  if not v_is_staff or not v_is_admin then
    raise exception 'FAIL: admin helper expectations failed';
  end if;

  insert into public.categories (id, name, slug, sort_order, is_active)
  values (v_admin_cat, 'RLS Admin Category', 'rls-admin-category', 913, true);

  update public.categories
  set description = 'admin-updated'
  where id = v_admin_cat;
  if not found then
    raise exception 'FAIL: admin cannot UPDATE category';
  end if;

  insert into public.brands (id, name, slug, sort_order, is_active)
  values (v_admin_brand, 'RLS Admin Brand', 'rls-admin-brand', 921, true);

  update public.brands
  set description = 'admin-brand-updated'
  where id = v_admin_brand;
  if not found then
    raise exception 'FAIL: admin cannot UPDATE brand';
  end if;

  insert into public.products (
    id, category_id, brand_id, name, slug, status, is_featured, published_at
  ) values (
    v_admin_product,
    v_admin_cat,
    v_admin_brand,
    'RLS Admin Product',
    'rls-admin-product',
    'active',
    false,
    timezone('utc', now())
  );

  update public.products
  set short_description = 'admin-product-updated'
  where id = v_admin_product;
  if not found then
    raise exception 'FAIL: admin cannot UPDATE product';
  end if;

  insert into public.product_variants (
    id, product_id, sku, name, price, is_active, is_default, sort_order
  ) values (
    v_admin_variant,
    v_admin_product,
    'RLS-SKU-ADMIN',
    'Admin Variant',
    175000,
    true,
    true,
    0
  );

  update public.product_variants
  set name = 'Admin Variant Updated'
  where id = v_admin_variant;
  if not found then
    raise exception 'FAIL: admin cannot UPDATE variant';
  end if;

  insert into public.product_images (
    id, product_id, storage_path, is_primary, sort_order
  ) values (
    v_admin_image,
    v_admin_product,
    'product-images/rls-admin.webp',
    true,
    0
  );

  update public.product_images
  set alt_text = 'admin-image-updated'
  where id = v_admin_image;
  if not found then
    raise exception 'FAIL: admin cannot UPDATE product_image';
  end if;

  insert into public.inventory (
    variant_id, quantity_on_hand, quantity_reserved, reorder_level, allow_backorder
  ) values (
    v_admin_variant, 6, 0, 1, false
  );

  update public.inventory
  set quantity_on_hand = quantity_on_hand + 1
  where variant_id = 'a6130000-0000-4000-8000-000000000001';
  if not found then
    raise exception 'FAIL: admin cannot UPDATE inventory';
  end if;

  update public.orders set status = 'preparing' where id = v_order_a;
  if not found then
    raise exception 'FAIL: admin cannot UPDATE order';
  end if;

  insert into public.order_status_history (
    order_id, from_status, to_status, changed_by, note
  ) values (
    v_order_a, 'confirmed', 'preparing', v_admin, 'admin-note'
  );

  delete from public.inventory where variant_id = v_admin_variant;
  if not found then
    raise exception 'FAIL: admin cannot DELETE inventory';
  end if;

  delete from public.product_images where id = v_admin_image;
  if not found then
    raise exception 'FAIL: admin cannot DELETE product_image';
  end if;

  delete from public.product_variants where id = v_admin_variant;
  if not found then
    raise exception 'FAIL: admin cannot DELETE variant';
  end if;

  delete from public.products where id = v_admin_product;
  if not found then
    raise exception 'FAIL: admin cannot DELETE product';
  end if;

  delete from public.brands where id = v_admin_brand;
  if not found then
    raise exception 'FAIL: admin cannot DELETE brand';
  end if;

  delete from public.categories where id = v_cat_id;
  if not found then
    raise exception 'FAIL: admin cannot DELETE staff category';
  end if;

  delete from public.categories where id = v_admin_cat;
  if not found then
    raise exception 'FAIL: admin cannot DELETE admin category';
  end if;

  perform pg_temp.rls_clear_auth();

  if (
    select status from public.orders where id = v_order_a
  ) is distinct from 'preparing' then
    raise exception 'FAIL: admin order UPDATE did not persist';
  end if;
  if (
    select count(*) from public.order_status_history where id = v_history_id
  ) <> 1 then
    raise exception 'FAIL: staff history row missing';
  end if;

  raise notice 'OK: staff/admin matrix + is_admin distinction';
exception
  when others then
    perform pg_temp.rls_clear_auth();
    raise;
end $$;

-- ---------------------------------------------------------------------------
-- 7. Storage policies (SELECT / INSERT / UPDATE / DELETE separately)
-- ---------------------------------------------------------------------------
do $$
declare
  v_a uuid := 'a6000000-0000-4000-8000-000000000001';
  v_b uuid := 'a6000000-0000-4000-8000-000000000002';
  v_staff uuid := 'a6000000-0000-4000-8000-000000000003';
  v_admin uuid := 'a6000000-0000-4000-8000-000000000004';
  v_product_obj uuid := 'a6900000-0000-4000-8000-000000000001';
  v_brand_obj uuid := 'a6900000-0000-4000-8000-000000000002';
  v_category_obj uuid := 'a6900000-0000-4000-8000-000000000003';
  v_avatar_a uuid := 'a6900000-0000-4000-8000-000000000004';
  v_avatar_b uuid := 'a6900000-0000-4000-8000-000000000005';
  v_staff_target uuid := 'a6900000-0000-4000-8000-000000000006';
  v_staff_insert uuid := 'a6900000-0000-4000-8000-000000000021';
  v_admin_insert uuid := 'a6900000-0000-4000-8000-000000000022';
  v_avatar_insert uuid := 'a6900000-0000-4000-8000-000000000023';
  v_count integer;
  v_public boolean;
  v_meta jsonb;
begin
  -- Allow direct DELETE in this local transaction so Storage RLS policies are
  -- exercised without the Storage API HTTP path (setting is transaction-local).
  perform set_config('storage.allow_delete_query', 'true', true);

  -- Bucket public flags.
  select public into v_public
  from storage.buckets where id = 'product-images';
  if v_public is distinct from true then
    raise exception 'FAIL: product-images bucket not public';
  end if;
  select public into v_public
  from storage.buckets where id = 'user-avatars';
  if v_public is distinct from false then
    raise exception 'FAIL: user-avatars bucket unexpectedly public';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'storage_product_images_public_read'
  ) then
    raise exception 'FAIL: missing storage_product_images_public_read policy';
  end if;

  -- Anon: catalog SELECT allowed; avatar SELECT denied; writes denied.
  perform pg_temp.rls_set_anon();
  perform pg_temp.assert_count(
    'anon product-images SELECT',
    format(
      $q$select count(*)::integer from storage.objects where id = %L$q$,
      v_product_obj
    ),
    1
  );
  perform pg_temp.assert_count(
    'anon brand-assets SELECT',
    format(
      $q$select count(*)::integer from storage.objects where id = %L$q$,
      v_brand_obj
    ),
    1
  );
  perform pg_temp.assert_count(
    'anon category-assets SELECT',
    format(
      $q$select count(*)::integer from storage.objects where id = %L$q$,
      v_category_obj
    ),
    1
  );
  perform pg_temp.assert_count(
    'anon avatar SELECT',
    format(
      $q$select count(*)::integer from storage.objects where id = %L$q$,
      v_avatar_a
    ),
    0
  );
  perform pg_temp.assert_denied_or_zero(
    'anon catalog INSERT',
    $q$insert into storage.objects (bucket_id, name)
       values ('product-images', 'rls-task006/anon.webp')$q$
  );
  perform pg_temp.assert_denied_or_zero(
    'anon catalog UPDATE',
    format(
      $q$update storage.objects
         set metadata = '{"mimetype":"image/webp","size":1}'::jsonb
         where id = %L$q$,
      v_product_obj
    )
  );
  perform pg_temp.assert_denied_or_zero(
    'anon catalog DELETE',
    format($q$delete from storage.objects where id = %L$q$, v_product_obj)
  );
  perform pg_temp.rls_clear_auth();

  -- Customer A: catalog read; catalog write denied; own avatar path OK.
  perform pg_temp.rls_set_auth(v_a);
  perform pg_temp.assert_count(
    'customer catalog SELECT',
    format(
      $q$select count(*)::integer from storage.objects where id = %L$q$,
      v_product_obj
    ),
    1
  );
  perform pg_temp.assert_denied_or_zero(
    'customer catalog INSERT',
    $q$insert into storage.objects (bucket_id, name)
       values ('product-images', 'rls-task006/customer.webp')$q$
  );
  perform pg_temp.assert_denied_or_zero(
    'customer catalog UPDATE',
    format(
      $q$update storage.objects
         set metadata = '{"mimetype":"image/webp","size":2}'::jsonb
         where id = %L$q$,
      v_staff_target
    )
  );
  perform pg_temp.assert_denied_or_zero(
    'customer catalog DELETE',
    format($q$delete from storage.objects where id = %L$q$, v_staff_target)
  );

  perform pg_temp.assert_count(
    'customer A own avatar SELECT',
    format(
      $q$select count(*)::integer from storage.objects where id = %L$q$,
      v_avatar_a
    ),
    1
  );
  perform pg_temp.assert_count(
    'customer A foreign avatar SELECT',
    format(
      $q$select count(*)::integer from storage.objects where id = %L$q$,
      v_avatar_b
    ),
    0
  );

  insert into storage.objects (id, bucket_id, name, metadata)
  values (
    v_avatar_insert,
    'user-avatars',
    'a6000000-0000-4000-8000-000000000001/extra.webp',
    '{"mimetype":"image/webp","size":8}'::jsonb
  );

  update storage.objects
  set metadata = '{"mimetype":"image/webp","size":9}'::jsonb
  where id = v_avatar_a;
  if not found then
    raise exception 'FAIL: customer A cannot UPDATE own avatar object';
  end if;

  perform pg_temp.assert_denied_or_zero(
    'customer A update B avatar',
    format(
      $q$update storage.objects
         set metadata = '{"mimetype":"image/webp","size":3}'::jsonb
         where id = %L$q$,
      v_avatar_b
    )
  );
  perform pg_temp.assert_denied_or_zero(
    'customer A delete B avatar',
    format($q$delete from storage.objects where id = %L$q$, v_avatar_b)
  );
  perform pg_temp.assert_denied_or_zero(
    'customer A insert under B path',
    $q$insert into storage.objects (bucket_id, name)
       values (
         'user-avatars',
         'a6000000-0000-4000-8000-000000000002/hack.webp'
       )$q$
  );

  delete from storage.objects where id = v_avatar_insert;
  if not found then
    raise exception 'FAIL: customer A cannot DELETE own avatar object';
  end if;

  perform pg_temp.rls_clear_auth();

  -- Confirm B avatar unchanged.
  select metadata into v_meta from storage.objects where id = v_avatar_b;
  if v_meta is distinct from '{"mimetype":"image/webp","size":16}'::jsonb then
    raise exception 'FAIL: B avatar mutated by A';
  end if;
  select count(*) into v_count
  from storage.objects where id = v_product_obj;
  if v_count <> 1 then
    raise exception 'FAIL: catalog object deleted by non-staff';
  end if;

  -- Staff catalog mutations (INSERT / UPDATE / DELETE separately).
  perform pg_temp.rls_set_auth(v_staff);
  insert into storage.objects (id, bucket_id, name, metadata)
  values (
    v_staff_insert,
    'product-images',
    'rls-task006/staff-insert.webp',
    '{"mimetype":"image/webp","size":4}'::jsonb
  );

  update storage.objects
  set metadata = '{"mimetype":"image/webp","size":5}'::jsonb
  where id = v_staff_target;
  if not found then
    raise exception 'FAIL: staff cannot UPDATE catalog object';
  end if;

  delete from storage.objects where id = v_staff_insert;
  if not found then
    raise exception 'FAIL: staff cannot DELETE catalog object';
  end if;

  -- Staff can read avatars.
  perform pg_temp.assert_count(
    'staff avatar A SELECT',
    format(
      $q$select count(*)::integer from storage.objects where id = %L$q$,
      v_avatar_a
    ),
    1
  );
  perform pg_temp.assert_count(
    'staff avatar B SELECT',
    format(
      $q$select count(*)::integer from storage.objects where id = %L$q$,
      v_avatar_b
    ),
    1
  );
  perform pg_temp.rls_clear_auth();

  if (
    select metadata from storage.objects where id = v_staff_target
  ) is distinct from '{"mimetype":"image/webp","size":5}'::jsonb then
    raise exception 'FAIL: staff catalog UPDATE did not persist';
  end if;

  -- Admin catalog INSERT / UPDATE / DELETE.
  perform pg_temp.rls_set_auth(v_admin);
  insert into storage.objects (id, bucket_id, name, metadata)
  values (
    v_admin_insert,
    'brand-assets',
    'rls-task006/admin-insert.webp',
    '{"mimetype":"image/webp","size":6}'::jsonb
  );
  update storage.objects
  set metadata = '{"mimetype":"image/webp","size":7}'::jsonb
  where id = v_brand_obj;
  if not found then
    raise exception 'FAIL: admin cannot UPDATE brand object';
  end if;
  delete from storage.objects where id = v_admin_insert;
  if not found then
    raise exception 'FAIL: admin cannot DELETE brand object';
  end if;
  perform pg_temp.rls_clear_auth();

  raise notice 'OK: storage SELECT/INSERT/UPDATE/DELETE matrix';
exception
  when others then
    perform pg_temp.rls_clear_auth();
    raise;
end $$;

-- ---------------------------------------------------------------------------
-- 8. RPC exposure (grants already asserted; light behavioral checks)
-- ---------------------------------------------------------------------------
do $$
declare
  v_a uuid := 'a6000000-0000-4000-8000-000000000001';
  v_count integer;
begin
  -- anon cannot execute checkout_cod (grant layer).
  perform pg_temp.rls_set_anon();
  perform pg_temp.assert_privilege_error(
    'anon checkout_cod EXECUTE',
    $q$select public.checkout_cod(
         'a6200000-0000-4000-8000-000000000001',
         'anon'
       )$q$
  );

  -- Public catalog RPCs remain callable.
  select count(*) into v_count
  from public.search_products('RLS Active Product', 5);
  if v_count < 1 then
    raise exception 'FAIL: anon search_products returned no rows';
  end if;

  select count(*) into v_count
  from public.get_variant_availability(
    'a6130000-0000-4000-8000-000000000001'
  );
  if v_count <> 1 then
    raise exception 'FAIL: anon get_variant_availability failed';
  end if;

  -- Trigger helpers not client-callable.
  perform pg_temp.assert_privilege_error(
    'anon prevent_profile_privilege_escalation',
    $q$select public.prevent_profile_privilege_escalation()$q$
  );
  perform pg_temp.rls_clear_auth();

  perform pg_temp.rls_set_auth(v_a);
  perform pg_temp.assert_privilege_error(
    'authenticated assign_order_number',
    $q$select public.assign_order_number()$q$
  );
  perform pg_temp.assert_privilege_error(
    'authenticated record_order_status_change',
    $q$select public.record_order_status_change()$q$
  );
  perform pg_temp.assert_privilege_error(
    'authenticated validate_product_image_variant',
    $q$select public.validate_product_image_variant()$q$
  );
  perform pg_temp.assert_privilege_error(
    'authenticated handle_new_user_profile',
    $q$select public.handle_new_user_profile()$q$
  );
  perform pg_temp.assert_privilege_error(
    'authenticated prevent_inventory_history_mutation',
    $q$select public.prevent_inventory_history_mutation()$q$
  );

  -- authenticated retains EXECUTE on checkout_cod (do not invoke full checkout).
  if not has_function_privilege(
    'authenticated', 'public.checkout_cod(uuid, text)', 'EXECUTE'
  ) then
    raise exception 'FAIL: authenticated lost checkout_cod EXECUTE mid-suite';
  end if;

  perform pg_temp.rls_clear_auth();
  raise notice 'OK: RPC exposure checks';
exception
  when others then
    perform pg_temp.rls_clear_auth();
    raise;
end $$;

-- ---------------------------------------------------------------------------
-- Fixture integrity before rollback
-- ---------------------------------------------------------------------------
do $$
begin
  if (
    select count(*) from auth.users
    where id in (
      'a6000000-0000-4000-8000-000000000001',
      'a6000000-0000-4000-8000-000000000002',
      'a6000000-0000-4000-8000-000000000003',
      'a6000000-0000-4000-8000-000000000004',
      'a6000000-0000-4000-8000-000000000005'
    )
  ) <> 5 then
    raise exception 'FAIL: expected five TASK-006 auth users before rollback';
  end if;

  if (
    select count(*) from storage.objects
    where id in (
      'a6900000-0000-4000-8000-000000000001',
      'a6900000-0000-4000-8000-000000000002',
      'a6900000-0000-4000-8000-000000000003',
      'a6900000-0000-4000-8000-000000000004',
      'a6900000-0000-4000-8000-000000000005',
      'a6900000-0000-4000-8000-000000000006'
    )
  ) <> 6 then
    raise exception 'FAIL: expected six TASK-006 storage fixtures';
  end if;

  raise notice 'OK: fixture integrity prior to ROLLBACK';
end $$;

rollback;

\echo '== TASK-006 done =='
