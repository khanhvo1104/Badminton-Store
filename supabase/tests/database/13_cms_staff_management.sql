-- Executable regression: CMS staff management (TASK-041).
--
-- Run against an already migrated + seeded disposable local database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/13_cms_staff_management.sql
--
-- Assert only scenario labels, IDs, counts, nullability, and SQLSTATEs —
-- never print JWTs, credentials, emails, or caught internals.

\set ON_ERROR_STOP on
\echo '== CMS staff management regression (TASK-041) =='

begin;

create or replace function pg_temp.stf_insert_user(
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

create or replace function pg_temp.stf_set_auth(p_user_id uuid)
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

create or replace function pg_temp.stf_clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

create or replace function pg_temp.stf_assert_authz_denied(
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
        perform pg_temp.stf_clear_auth();
        raise exception 'FAIL: % raised 42501 with unexpected message', p_label;
      end if;
    when others then
      if sqlstate = '42501' and sqlerrm = 'not authorized' then
        v_denied := true;
      else
        perform pg_temp.stf_clear_auth();
        raise exception 'FAIL: % raised % instead of authz denial', p_label, sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.stf_clear_auth();
    raise exception 'FAIL: % succeeded unexpectedly', p_label;
  end if;
end;
$$;

-- Fixtures
-- admin A (sole active admin under test), admin B (second admin), staff S, customer C
do $$
declare
  v_admin_a uuid := 'a4100000-0000-4000-8000-000000000101';
  v_admin_b uuid := 'a4100000-0000-4000-8000-000000000102';
  v_staff uuid := 'a4100000-0000-4000-8000-000000000103';
  v_customer uuid := 'a4100000-0000-4000-8000-000000000104';
begin
  delete from public.staff_management_events
  where actor_id in (v_admin_a, v_admin_b, v_staff)
     or target_id in (v_admin_a, v_admin_b, v_staff, v_customer);

  delete from public.profiles
  where id in (v_admin_a, v_admin_b, v_staff, v_customer);
  delete from auth.users
  where id in (v_admin_a, v_admin_b, v_staff, v_customer);

  perform pg_temp.stf_insert_user(v_admin_a, 'staff-admin-a@example.invalid');
  perform pg_temp.stf_insert_user(v_admin_b, 'staff-admin-b@example.invalid');
  perform pg_temp.stf_insert_user(v_staff, 'staff-member-s@example.invalid');
  perform pg_temp.stf_insert_user(v_customer, 'staff-customer-c@example.invalid');

  perform set_config('app.trusted_staff_management', '1', true);
  update public.profiles set role = 'admin', is_active = true, full_name = 'Admin A'
  where id = v_admin_a;
  update public.profiles set role = 'admin', is_active = true, full_name = 'Admin B'
  where id = v_admin_b;
  update public.profiles set role = 'staff', is_active = true, full_name = 'Staff S'
  where id = v_staff;
  update public.profiles set role = 'customer', is_active = true, full_name = 'Customer C'
  where id = v_customer;
  perform set_config('app.trusted_staff_management', '', true);
end;
$$;

\echo 'PASS: fixtures inserted'

-- EXECUTE matrix
do $$
begin
  if has_function_privilege('anon', 'public.list_cms_staff(text,text,text,text,integer,integer)', 'EXECUTE') then
    raise exception 'FAIL: anon may execute list_cms_staff';
  end if;
  if not has_function_privilege('authenticated', 'public.list_cms_staff(text,text,text,text,integer,integer)', 'EXECUTE') then
    raise exception 'FAIL: authenticated missing list_cms_staff EXECUTE';
  end if;
  if has_function_privilege('anon', 'public.update_cms_staff(uuid,text,boolean)', 'EXECUTE') then
    raise exception 'FAIL: anon may execute update_cms_staff';
  end if;
  if not has_function_privilege('authenticated', 'public.update_cms_staff(uuid,text,boolean)', 'EXECUTE') then
    raise exception 'FAIL: authenticated missing update_cms_staff EXECUTE';
  end if;
end;
$$;

\echo 'PASS: function EXECUTE matrix'

do $$
declare
  v_list text;
begin
  v_list := $q$select * from public.list_cms_staff()$q$;

  perform pg_temp.stf_assert_authz_denied('anon list_cms_staff', v_list);

  perform pg_temp.stf_set_auth('a4100000-0000-4000-8000-000000000103');
  perform pg_temp.stf_assert_authz_denied('staff list_cms_staff', v_list);
  perform pg_temp.stf_clear_auth();

  perform pg_temp.stf_set_auth('a4100000-0000-4000-8000-000000000104');
  perform pg_temp.stf_assert_authz_denied('customer list_cms_staff', v_list);
  perform pg_temp.stf_clear_auth();
end;
$$;

\echo 'PASS: negative list authorization'

do $$
declare
  v_count integer;
  v_customer_visible integer;
begin
  perform pg_temp.stf_set_auth('a4100000-0000-4000-8000-000000000101');

  select count(*)::integer, count(*) filter (where role = 'customer')::integer
  into v_count, v_customer_visible
  from public.list_cms_staff('', 'all', 'all', 'name_asc', 0, 20);

  if v_count < 3 then
    raise exception 'FAIL: expected at least 3 staff/admin rows, got %', v_count;
  end if;
  if v_customer_visible <> 0 then
    raise exception 'FAIL: customer profile leaked into staff directory';
  end if;

  perform pg_temp.stf_clear_auth();
end;
$$;

\echo 'PASS: admin list success and customer exclusion'

do $$
begin
  if to_regprocedure('public.enforce_staff_profile_mutation_boundary()') is null then
    raise exception 'FAIL: missing enforce_staff_profile_mutation_boundary()';
  end if;
end;
$$;

\echo 'PASS: direct role mutation boundary contract'

do $$
declare
  v_result uuid;
begin
  perform pg_temp.stf_set_auth('a4100000-0000-4000-8000-000000000101');
  v_result := public.update_cms_staff(
    'a4100000-0000-4000-8000-000000000103',
    'admin',
    null
  );
  if v_result <> 'a4100000-0000-4000-8000-000000000103' then
    raise exception 'FAIL: update_cms_staff returned unexpected id';
  end if;
  perform pg_temp.stf_clear_auth();
end;
$$;

\echo 'PASS: admin promote via RPC'

do $$
declare
  v_self_deactivate text;
  v_self_demote text;
  v_last_admin text;
begin
  v_self_deactivate :=
    $q$select public.update_cms_staff('a4100000-0000-4000-8000-000000000101', null, false)$q$;
  v_self_demote :=
    $q$select public.update_cms_staff('a4100000-0000-4000-8000-000000000101', 'staff', null)$q$;
  v_last_admin :=
    $q$select public.update_cms_staff('a4100000-0000-4000-8000-000000000101', null, false)$q$;

  perform pg_temp.stf_set_auth('a4100000-0000-4000-8000-000000000101');
  perform pg_temp.stf_assert_authz_denied('self deactivate', v_self_deactivate);
  perform pg_temp.stf_clear_auth();

  perform pg_temp.stf_set_auth('a4100000-0000-4000-8000-000000000101');
  perform pg_temp.stf_assert_authz_denied('self demote', v_self_demote);
  perform pg_temp.stf_clear_auth();

  update public.profiles
  set is_active = false
  where id = 'a4100000-0000-4000-8000-000000000102';

  perform pg_temp.stf_set_auth('a4100000-0000-4000-8000-000000000101');
  perform pg_temp.stf_assert_authz_denied('last admin deactivate', v_last_admin);
  perform pg_temp.stf_clear_auth();

  update public.profiles
  set is_active = true
  where id = 'a4100000-0000-4000-8000-000000000102';
end;
$$;

\echo 'PASS: last active admin protection'

do $$
declare
  v_events integer;
begin
  perform pg_temp.stf_set_auth('a4100000-0000-4000-8000-000000000101');
  select count(*)::integer into v_events
  from public.staff_management_events;
  if v_events < 1 then
    raise exception 'FAIL: expected audit events after RPC mutation';
  end if;
  perform pg_temp.stf_clear_auth();

  perform pg_temp.stf_set_auth('a4100000-0000-4000-8000-000000000104');
  select count(*)::integer into v_events
  from public.staff_management_events;
  if v_events <> 0 then
    raise exception 'FAIL: customer read audit events';
  end if;
  perform pg_temp.stf_clear_auth();
end;
$$;

\echo 'PASS: self-deactivation and self-demotion denied'

\echo 'PASS: audit RLS'

rollback;

\echo '== CMS staff management regression complete =='
