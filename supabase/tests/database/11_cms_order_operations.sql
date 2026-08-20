-- Executable regression: CMS order list + status transitions (TASK-039).
--
-- Run against an already migrated + seeded disposable local database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/11_cms_order_operations.sql
--
-- Assert only scenario labels, IDs, counts, nullability, and SQLSTATEs —
-- never print JWTs, credentials, or caught internals.

\set ON_ERROR_STOP on
\echo '== CMS order operations regression (TASK-039) =='

begin;

create or replace function pg_temp.ord_insert_user(
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

create or replace function pg_temp.ord_set_auth(p_user_id uuid)
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

create or replace function pg_temp.ord_clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

create or replace function pg_temp.ord_assert_authz_denied(
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
        perform pg_temp.ord_clear_auth();
        raise exception 'FAIL: % raised 42501 with unexpected message', p_label;
      end if;
    when others then
      if sqlstate = '42501' and sqlerrm = 'not authorized' then
        v_denied := true;
      else
        perform pg_temp.ord_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.ord_clear_auth();
    raise exception 'FAIL: % expected authorization denial', p_label;
  end if;
end;
$$;

create or replace function pg_temp.ord_assert_execute_denied(
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
        perform pg_temp.ord_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.ord_clear_auth();
    raise exception 'FAIL: % expected EXECUTE denial', p_label;
  end if;
end;
$$;

create or replace function pg_temp.ord_assert_invalid(
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
    when others then
      if sqlstate = '22023' then
        v_denied := true;
      else
        perform pg_temp.ord_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.ord_clear_auth();
    raise exception 'FAIL: % expected invalid request', p_label;
  end if;
end;
$$;

do $$
declare
  v_staff uuid := 'b3900000-0000-4000-8000-000000000101';
  v_admin uuid := 'b3900000-0000-4000-8000-000000000102';
  v_customer uuid := 'b3900000-0000-4000-8000-000000000103';
  v_inactive uuid := 'b3900000-0000-4000-8000-000000000104';
  v_category uuid := 'b3910000-0000-4000-8000-000000000101';
  v_product uuid := 'b3920000-0000-4000-8000-000000000101';
  v_variant uuid := 'b3930000-0000-4000-8000-000000000101';
  v_order uuid := 'b3940000-0000-4000-8000-000000000101';
  v_order_cancel uuid := 'b3940000-0000-4000-8000-000000000102';
  v_order_deliver uuid := 'b3940000-0000-4000-8000-000000000103';
  v_list_sig text :=
    'public.list_cms_orders(text, text, text, timestamp with time zone, timestamp with time zone, text, integer, integer)';
  v_transition_sig text := 'public.transition_cms_order_status(uuid, text, text)';
  v_list text;
  v_transition text;
  v_status text;
  v_reserved integer;
  v_on_hand integer;
  v_history integer;
  v_note text;
  v_cancelled_at timestamptz;
  v_returned_id uuid;
  v_proconfig_arr text[];
  v_prosecdef boolean;
  v_provolatile char;
begin
  perform pg_temp.ord_insert_user(v_staff, 'orders-staff@example.invalid');
  perform pg_temp.ord_insert_user(v_admin, 'orders-admin@example.invalid');
  perform pg_temp.ord_insert_user(v_customer, 'orders-customer@example.invalid');
  perform pg_temp.ord_insert_user(v_inactive, 'orders-inactive@example.invalid');

  update public.profiles
  set role = 'staff', full_name = 'Orders Staff', is_active = true
  where id = v_staff;
  update public.profiles
  set role = 'admin', full_name = 'Orders Admin', is_active = true
  where id = v_admin;
  update public.profiles
  set role = 'customer', full_name = 'Orders Customer', is_active = true
  where id = v_customer;
  update public.profiles
  set role = 'staff', full_name = 'Orders Inactive', is_active = false
  where id = v_inactive;

  insert into public.categories (id, name, slug, sort_order, is_active)
  values (v_category, 'Orders Category', 'orders-category', 390, true);

  insert into public.products (
    id, category_id, name, slug, status, is_featured, published_at
  ) values (
    v_product, v_category, 'Orders Product', 'orders-product',
    'active', false, timezone('utc', now())
  );

  insert into public.product_variants (
    id, product_id, sku, name, price, is_default, is_active, sort_order
  ) values (
    v_variant, v_product, 'ORD-SKU-1', 'Default', 100000, true, true, 0
  );

  insert into public.inventory (
    variant_id, quantity_on_hand, quantity_reserved, reorder_level, allow_backorder
  ) values (
    v_variant, 20, 5, 0, false
  );

  insert into public.orders (
    id, order_number, user_id, status,
    subtotal, discount_total, shipping_fee, grand_total,
    recipient_name, recipient_phone, shipping_address
  ) values
  (
    v_order, 'BDM-ORD-OPS-001', v_customer, 'pending',
    200000, 0, 0, 200000,
    'Recipient One', '0901111111',
    '{"recipient_name":"Recipient One","phone_number":"0901111111","province_name":"HN","district_name":"Dong Da","ward_name":"Cat Linh","street_address":"1 Main"}'::jsonb
  ),
  (
    v_order_cancel, 'BDM-ORD-OPS-002', v_customer, 'confirmed',
    100000, 0, 0, 100000,
    'Recipient Two', '0902222222',
    '{"recipient_name":"Recipient Two","phone_number":"0902222222"}'::jsonb
  ),
  (
    v_order_deliver, 'BDM-ORD-OPS-003', v_customer, 'shipping',
    200000, 0, 0, 200000,
    'Recipient Three', '0903333333',
    '{"recipient_name":"Recipient Three","phone_number":"0903333333"}'::jsonb
  );

  insert into public.order_items (
    order_id, product_id, variant_id, product_name, variant_name, sku,
    unit_price, quantity, line_total
  ) values
  (v_order, v_product, v_variant, 'Orders Product', 'Default', 'ORD-SKU-1', 100000, 2, 200000),
  (v_order_cancel, v_product, v_variant, 'Orders Product', 'Default', 'ORD-SKU-1', 100000, 1, 100000),
  (v_order_deliver, v_product, v_variant, 'Orders Product', 'Default', 'ORD-SKU-1', 100000, 2, 200000);

  select p.provolatile, p.prosecdef, p.proconfig
  into v_provolatile, v_prosecdef, v_proconfig_arr
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'list_cms_orders';
  if v_provolatile is distinct from 's' then
    raise exception 'FAIL: list_cms_orders is not STABLE';
  end if;
  if v_prosecdef then
    raise exception 'FAIL: list_cms_orders is not SECURITY INVOKER';
  end if;
  if v_proconfig_arr is null
     or not exists (
       select 1
       from unnest(v_proconfig_arr) as cfg(val)
       where cfg.val in ('search_path=', 'search_path=""')
     )
  then
    raise exception 'FAIL: list_cms_orders search_path is not empty';
  end if;

  select p.provolatile, p.prosecdef, p.proconfig
  into v_provolatile, v_prosecdef, v_proconfig_arr
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'transition_cms_order_status';
  if v_provolatile is distinct from 'v' then
    raise exception 'FAIL: transition_cms_order_status is not VOLATILE';
  end if;
  if not v_prosecdef then
    raise exception 'FAIL: transition_cms_order_status is not SECURITY DEFINER';
  end if;
  if v_proconfig_arr is null
     or not exists (
       select 1
       from unnest(v_proconfig_arr) as cfg(val)
       where cfg.val in ('search_path=', 'search_path=""')
     )
  then
    raise exception 'FAIL: transition_cms_order_status search_path is not empty';
  end if;

  if has_function_privilege('public', v_list_sig, 'EXECUTE')
     or has_function_privilege('anon', v_list_sig, 'EXECUTE') then
    raise exception 'FAIL: list_cms_orders EXECUTE too broad';
  end if;
  if has_function_privilege('public', v_transition_sig, 'EXECUTE')
     or has_function_privilege('anon', v_transition_sig, 'EXECUTE') then
    raise exception 'FAIL: transition_cms_order_status EXECUTE too broad';
  end if;
  if not has_function_privilege('authenticated', v_list_sig, 'EXECUTE')
     or not has_function_privilege('service_role', v_list_sig, 'EXECUTE') then
    raise exception 'FAIL: list_cms_orders missing EXECUTE grant';
  end if;
  if not has_function_privilege('authenticated', v_transition_sig, 'EXECUTE')
     or not has_function_privilege('service_role', v_transition_sig, 'EXECUTE') then
    raise exception 'FAIL: transition_cms_order_status missing EXECUTE grant';
  end if;

  if has_table_privilege('authenticated', 'public.orders', 'UPDATE') then
    raise exception 'FAIL: authenticated still has UPDATE on orders';
  end if;
  if not has_table_privilege('authenticated', 'public.orders', 'SELECT') then
    raise exception 'FAIL: authenticated missing SELECT on orders';
  end if;

  if has_function_privilege(
    'authenticated', 'public.record_order_status_change()', 'EXECUTE'
  ) then
    raise exception 'FAIL: authenticated has EXECUTE on record_order_status_change';
  end if;

  v_list :=
    $q$select order_id from public.list_cms_orders('', 'all', 'all', null, null, 'placed_desc', 0, 20)$q$;
  v_transition := format(
    $q$select order_id from public.transition_cms_order_status(%L::uuid, 'confirmed', null)$q$,
    v_order
  );

  set local role anon;
  perform pg_temp.ord_assert_execute_denied('anon list_cms_orders', v_list);
  perform pg_temp.ord_assert_execute_denied(
    'anon transition_cms_order_status', v_transition
  );
  reset role;

  perform pg_temp.ord_set_auth(v_customer);
  perform pg_temp.ord_assert_authz_denied('customer list_cms_orders', v_list);
  perform pg_temp.ord_assert_authz_denied(
    'customer transition_cms_order_status', v_transition
  );
  perform pg_temp.ord_clear_auth();

  perform pg_temp.ord_set_auth(v_inactive);
  perform pg_temp.ord_assert_authz_denied('inactive list_cms_orders', v_list);
  perform pg_temp.ord_assert_authz_denied(
    'inactive transition_cms_order_status', v_transition
  );
  perform pg_temp.ord_clear_auth();

  -- Staff cannot direct-UPDATE status; RPC succeeds.
  perform pg_temp.ord_set_auth(v_staff);
  begin
    update public.orders set status = 'confirmed' where id = v_order;
    perform pg_temp.ord_clear_auth();
    raise exception 'FAIL: staff direct UPDATE on orders succeeded';
  exception
    when insufficient_privilege then
      null;
    when others then
      if sqlstate is distinct from '42501' then
        perform pg_temp.ord_clear_auth();
        raise;
      end if;
  end;

  select order_id into v_returned_id
  from public.transition_cms_order_status(v_order, 'confirmed', 'staff confirmed');
  if v_returned_id is distinct from v_order then
    raise exception 'FAIL: transition return mismatch';
  end if;

  select status, cancelled_at into v_status, v_cancelled_at
  from public.orders where id = v_order;
  if v_status is distinct from 'confirmed' or v_cancelled_at is not null then
    raise exception 'FAIL: confirmed transition state unexpected';
  end if;

  select count(*) into v_history
  from public.order_status_history
  where order_id = v_order
    and from_status = 'pending'
    and to_status = 'confirmed'
    and changed_by = v_staff;
  if v_history <> 1 then
    raise exception 'FAIL: expected exactly one pending→confirmed history row';
  end if;

  select note into v_note
  from public.order_status_history
  where order_id = v_order
    and from_status = 'pending'
    and to_status = 'confirmed'
  order by created_at desc
  limit 1;
  if v_note is distinct from 'staff confirmed' then
    raise exception 'FAIL: staff note was not stamped on history row';
  end if;

  -- Invalid transition
  perform pg_temp.ord_assert_invalid(
    'skip to shipping',
    format(
      $q$select order_id from public.transition_cms_order_status(%L::uuid, 'shipping', null)$q$,
      v_order
    )
  );

  -- Cancel releases reservation
  select quantity_reserved into v_reserved
  from public.inventory where variant_id = v_variant;

  perform public.transition_cms_order_status(
    v_order_cancel, 'cancelled', 'cancel note'
  );

  if (
    select quantity_reserved from public.inventory where variant_id = v_variant
  ) is distinct from v_reserved - 1 then
    raise exception 'FAIL: cancel did not release reservation';
  end if;

  if (
    select status from public.orders where id = v_order_cancel
  ) is distinct from 'cancelled' then
    raise exception 'FAIL: cancel status not persisted';
  end if;

  if (
    select cancelled_at from public.orders where id = v_order_cancel
  ) is null then
    raise exception 'FAIL: cancelled_at not set';
  end if;

  -- Deliver consumes reserved + on-hand
  select quantity_on_hand, quantity_reserved
  into v_on_hand, v_reserved
  from public.inventory where variant_id = v_variant;

  perform public.transition_cms_order_status(v_order_deliver, 'delivered', null);

  if (
    select quantity_on_hand from public.inventory where variant_id = v_variant
  ) is distinct from v_on_hand - 2 then
    raise exception 'FAIL: deliver did not consume on-hand';
  end if;
  if (
    select quantity_reserved from public.inventory where variant_id = v_variant
  ) is distinct from v_reserved - 2 then
    raise exception 'FAIL: deliver did not consume reserved';
  end if;

  -- Returned does not restock
  select quantity_on_hand, quantity_reserved
  into v_on_hand, v_reserved
  from public.inventory where variant_id = v_variant;

  perform public.transition_cms_order_status(v_order_deliver, 'returned', null);

  if (
    select quantity_on_hand from public.inventory where variant_id = v_variant
  ) is distinct from v_on_hand
     or (
       select quantity_reserved from public.inventory where variant_id = v_variant
     ) is distinct from v_reserved then
    raise exception 'FAIL: returned auto-restocked inventory';
  end if;

  -- List search / bounds
  if not exists (
    select 1
    from public.list_cms_orders(
      'ORD-OPS-001', 'all', 'all', null, null, 'placed_desc', 0, 20
    )
    where order_id = v_order
  ) then
    raise exception 'FAIL: list_cms_orders search missed order number';
  end if;

  perform pg_temp.ord_assert_invalid(
    'list limit too high',
    $q$select order_id from public.list_cms_orders('', 'all', 'all', null, null, 'placed_desc', 0, 51)$q$
  );
  perform pg_temp.ord_assert_invalid(
    'list bad status',
    $q$select order_id from public.list_cms_orders('', 'nope', 'all', null, null, 'placed_desc', 0, 20)$q$
  );

  -- Admin can also transition remaining path
  perform pg_temp.ord_clear_auth();
  perform pg_temp.ord_set_auth(v_admin);
  perform public.transition_cms_order_status(v_order, 'preparing', null);
  perform public.transition_cms_order_status(v_order, 'shipping', null);
  perform pg_temp.ord_clear_auth();

  raise notice 'OK: CMS order operations regression';
end;
$$;

rollback;

\echo '== CMS order operations regression PASSED =='
