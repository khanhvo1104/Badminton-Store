-- Executable regression: internal trigger helpers must not be directly
-- callable by client roles after EXECUTE lockdown, while owning triggers
-- continue to fire through normal table operations.
--
-- Run against an already migrated + seeded disposable local database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/04_trigger_function_execute.sql
--
-- Fixtures run inside a transaction and roll back. Do not print tokens,
-- secrets, cost_price values, order payloads, or full JWT claims.

\echo '== trigger helper EXECUTE lockdown regression =='

begin;

-- ---------------------------------------------------------------------------
-- Catalog privileges: PUBLIC / anon / authenticated denied; service_role OK
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
        raise exception
          'FAIL: % still has EXECUTE on %',
          grantee,
          sig;
      end if;
    end loop;

    if not has_function_privilege('service_role', sig, 'EXECUTE') then
      raise exception
        'FAIL: service_role missing EXECUTE on %',
        sig;
    end if;
  end loop;

  raise notice
    'OK: protected trigger helpers — PUBLIC/anon/authenticated denied; service_role granted';
end $$;

-- ---------------------------------------------------------------------------
-- Direct client calls must fail with insufficient_privilege (42501)
-- before any trigger-only runtime error.
-- ---------------------------------------------------------------------------
create or replace function pg_temp.assert_client_execute_denied(
  p_role text,
  p_signature text,
  p_call_sql text
)
returns void
language plpgsql
as $$
declare
  v_denied boolean := false;
begin
  begin
    execute format('set local role %I', p_role);
    execute p_call_sql;
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate = '42501' then
        v_denied := true;
      else
        execute 'reset role';
        raise exception
          'FAIL: % direct call to % raised unexpected SQLSTATE % (want 42501): %',
          p_role,
          p_signature,
          sqlstate,
          sqlerrm;
      end if;
  end;

  execute 'reset role';

  if not v_denied then
    raise exception
      'FAIL: % was able to EXECUTE % directly',
      p_role,
      p_signature;
  end if;
end;
$$;

do $$
declare
  role_name text;
begin
  foreach role_name in array array['anon', 'authenticated'] loop
    perform pg_temp.assert_client_execute_denied(
      role_name,
      'public.prevent_profile_privilege_escalation()',
      'select public.prevent_profile_privilege_escalation()'
    );
    perform pg_temp.assert_client_execute_denied(
      role_name,
      'public.assign_order_number()',
      'select public.assign_order_number()'
    );
    perform pg_temp.assert_client_execute_denied(
      role_name,
      'public.record_order_status_change()',
      'select public.record_order_status_change()'
    );
    perform pg_temp.assert_client_execute_denied(
      role_name,
      'public.validate_product_image_variant()',
      'select public.validate_product_image_variant()'
    );
    perform pg_temp.assert_client_execute_denied(
      role_name,
      'public.prevent_inventory_history_mutation()',
      'select public.prevent_inventory_history_mutation()'
    );
  end loop;

  raise notice 'OK: anon/authenticated direct EXECUTE denied with 42501';
end $$;

-- ---------------------------------------------------------------------------
-- Auth helpers / disposable fixtures (rolled back)
-- ---------------------------------------------------------------------------
create or replace function pg_temp.trigger_test_insert_user(
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
    crypt('trigger-test-password', gen_salt('bf')),
    timezone('utc', now()),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    timezone('utc', now()),
    timezone('utc', now())
  );
end;
$$;

create or replace function pg_temp.trigger_test_set_auth(p_user_id uuid)
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

create or replace function pg_temp.trigger_test_clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

select pg_temp.trigger_test_insert_user(
  'a7000000-0000-4000-8000-000000000001',
  'trigger-profile@example.invalid'
);

select pg_temp.trigger_test_insert_user(
  'a7000000-0000-4000-8000-000000000002',
  'trigger-order@example.invalid'
);

-- ---------------------------------------------------------------------------
-- Profile trigger still blocks privilege escalation on self-update
-- ---------------------------------------------------------------------------
do $$
declare
  v_user_id uuid := 'a7000000-0000-4000-8000-000000000001';
  v_role text;
  v_is_active boolean;
  v_full_name text;
begin
  update public.profiles
  set full_name = 'Trigger Profile Baseline'
  where id = v_user_id;

  perform pg_temp.trigger_test_set_auth(v_user_id);

  update public.profiles
  set
    full_name = 'Trigger Profile Allowed',
    role = 'admin',
    is_active = false
  where id = v_user_id;

  perform pg_temp.trigger_test_clear_auth();

  select role, is_active, full_name
  into v_role, v_is_active, v_full_name
  from public.profiles
  where id = v_user_id;

  if v_full_name is distinct from 'Trigger Profile Allowed' then
    raise exception
      'FAIL: benign full_name update was not applied after EXECUTE revoke';
  end if;

  if v_role is distinct from 'customer' then
    raise exception
      'FAIL: profiles_prevent_privilege_escalation did not preserve role';
  end if;

  if v_is_active is distinct from true then
    raise exception
      'FAIL: profiles_prevent_privilege_escalation did not preserve is_active';
  end if;

  raise notice
    'OK: profile privilege-escalation trigger still fires for authenticated self-update';
end $$;

-- ---------------------------------------------------------------------------
-- Order number + status-history triggers still fire via service_role writes
-- ---------------------------------------------------------------------------
do $$
declare
  v_user_id uuid := 'a7000000-0000-4000-8000-000000000002';
  v_order_id uuid := 'b7000000-0000-4000-8000-000000000001';
  v_order_number text;
  v_history_count integer;
  v_from_status text;
  v_to_status text;
begin
  set local role service_role;

  insert into public.orders (
    id,
    order_number,
    user_id,
    subtotal,
    discount_total,
    shipping_fee,
    grand_total,
    recipient_name,
    recipient_phone,
    shipping_address
  ) values (
    v_order_id,
    '',
    v_user_id,
    100,
    0,
    0,
    100,
    'Trigger Order User',
    '0907000002',
    '{"line1":"1 Test St"}'::jsonb
  );

  select order_number into v_order_number
  from public.orders
  where id = v_order_id;

  if v_order_number is null
     or btrim(v_order_number) = ''
     or v_order_number !~ '^BDM-[0-9]{8}-[A-Z0-9]{6}$' then
    raise exception
      'FAIL: orders_assign_order_number did not produce expected format';
  end if;

  select count(*)::integer into v_history_count
  from public.order_status_history
  where order_id = v_order_id;

  if v_history_count <> 1 then
    raise exception
      'FAIL: expected exactly 1 initial order_status_history row, got %',
      v_history_count;
  end if;

  select from_status, to_status
  into v_from_status, v_to_status
  from public.order_status_history
  where order_id = v_order_id;

  if v_from_status is not null or v_to_status is distinct from 'pending' then
    raise exception
      'FAIL: initial status history row has unexpected from/to states';
  end if;

  update public.orders
  set status = 'confirmed'
  where id = v_order_id;

  select count(*)::integer into v_history_count
  from public.order_status_history
  where order_id = v_order_id;

  if v_history_count <> 2 then
    raise exception
      'FAIL: expected 2 history rows after status change, got %',
      v_history_count;
  end if;

  select count(*)::integer into v_history_count
  from public.order_status_history
  where order_id = v_order_id
    and from_status is not distinct from 'pending'
    and to_status is not distinct from 'confirmed';

  if v_history_count <> 1 then
    raise exception
      'FAIL: expected exactly 1 pending→confirmed history row, got %',
      v_history_count;
  end if;

  update public.orders
  set status = 'confirmed'
  where id = v_order_id;

  select count(*)::integer into v_history_count
  from public.order_status_history
  where order_id = v_order_id;

  if v_history_count <> 2 then
    raise exception
      'FAIL: no-op status update created extra history rows (count=%)',
      v_history_count;
  end if;

  reset role;

  raise notice
    'OK: order number and status-history triggers still fire under service_role';
exception
  when others then
    reset role;
    raise;
end $$;

\echo '== trigger helper EXECUTE lockdown regression PASSED =='

rollback;
