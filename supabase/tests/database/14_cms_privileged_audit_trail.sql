-- Executable regression: CMS privileged audit ledger (TASK-042).
--
-- Run against an already migrated + seeded disposable local database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/14_cms_privileged_audit_trail.sql

\set ON_ERROR_STOP on
\echo '== CMS privileged audit trail regression (TASK-042) =='

begin;

create or replace function pg_temp.aud_insert_user(
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

create or replace function pg_temp.aud_set_auth(p_user_id uuid)
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

create or replace function pg_temp.aud_clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

create or replace function pg_temp.aud_cleanup_events()
returns void
language plpgsql
as $$
begin
  perform set_config('app.cms_audit_test_cleanup', '1', true);
  delete from public.cms_privileged_audit_events;
  perform set_config('app.cms_audit_test_cleanup', '', true);
end;
$$;

do $$
declare
  v_admin uuid := 'a4200000-0000-4000-8000-000000000101';
  v_staff uuid := 'a4200000-0000-4000-8000-000000000102';
  v_customer uuid := 'a4200000-0000-4000-8000-000000000103';
  v_category uuid := '10000000-0000-4000-8000-000000000099';
begin
  perform pg_temp.aud_cleanup_events();

  delete from public.staff_management_events
  where actor_id in (v_admin, v_staff)
     or target_id in (v_admin, v_staff, v_customer);
  delete from public.profiles
  where id in (v_admin, v_staff, v_customer);
  delete from auth.users
  where id in (v_admin, v_staff, v_customer);
  delete from public.categories where id = v_category;

  perform pg_temp.aud_insert_user(v_admin, 'audit-admin@example.invalid');
  perform pg_temp.aud_insert_user(v_staff, 'audit-staff@example.invalid');
  perform pg_temp.aud_insert_user(v_customer, 'audit-customer@example.invalid');

  perform set_config('app.trusted_staff_management', '1', true);
  update public.profiles
  set role = 'admin', is_active = true, full_name = 'Audit Admin'
  where id = v_admin;
  update public.profiles
  set role = 'staff', is_active = true, full_name = 'Audit Staff'
  where id = v_staff;
  update public.profiles
  set role = 'customer', is_active = true, full_name = 'Audit Customer'
  where id = v_customer;
  perform set_config('app.trusted_staff_management', '', true);
end;
$$;

\echo 'PASS: fixtures inserted'

-- Grant / EXECUTE matrix
do $$
begin
  if has_table_privilege('anon', 'public.cms_privileged_audit_events', 'SELECT') then
    raise exception 'FAIL: anon may SELECT cms_privileged_audit_events';
  end if;
  if has_table_privilege('authenticated', 'public.cms_privileged_audit_events', 'INSERT') then
    raise exception 'FAIL: authenticated may INSERT cms_privileged_audit_events';
  end if;
  if has_table_privilege('authenticated', 'public.cms_privileged_audit_events', 'UPDATE') then
    raise exception 'FAIL: authenticated may UPDATE cms_privileged_audit_events';
  end if;
  if has_table_privilege('authenticated', 'public.cms_privileged_audit_events', 'DELETE') then
    raise exception 'FAIL: authenticated may DELETE cms_privileged_audit_events';
  end if;
  if not has_table_privilege('authenticated', 'public.cms_privileged_audit_events', 'SELECT') then
    raise exception 'FAIL: authenticated missing SELECT grant on cms_privileged_audit_events';
  end if;

  if has_function_privilege(
    'public',
    'public.list_cms_privileged_audit_events(text,text,uuid,timestamptz,timestamptz,timestamptz,uuid,integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: PUBLIC has EXECUTE on list_cms_privileged_audit_events';
  end if;
  if not has_function_privilege(
    'authenticated',
    'public.list_cms_privileged_audit_events(text,text,uuid,timestamptz,timestamptz,timestamptz,uuid,integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: authenticated missing EXECUTE on list_cms_privileged_audit_events';
  end if;
  if has_function_privilege(
    'service_role',
    'public.list_cms_privileged_audit_events(text,text,uuid,timestamptz,timestamptz,timestamptz,uuid,integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: service_role has EXECUTE on list_cms_privileged_audit_events';
  end if;
end;
$$;

\echo 'PASS: grant and EXECUTE matrix'

-- Immutability + direct insert denial
do $$
declare
  v_admin uuid := 'a4200000-0000-4000-8000-000000000101';
  v_event uuid;
  v_count integer;
begin
  perform pg_temp.aud_set_auth(v_admin);

  begin
    insert into public.cms_privileged_audit_events (
      actor_id, entity_type, entity_id, action
    ) values (
      v_admin,
      'category',
      '10000000-0000-4000-8000-000000000001',
      'create'
    );
    raise exception 'FAIL: direct INSERT into cms_privileged_audit_events succeeded';
  exception
    when others then
      if sqlstate <> '42501' then
        raise;
      end if;
  end;

  select count(*) into v_count from public.cms_privileged_audit_events;
  if v_count <> 0 then
    raise exception 'FAIL: direct INSERT left audit rows behind';
  end if;

  perform pg_temp.aud_clear_auth();
end;
$$;

\echo 'PASS: direct INSERT denied'

-- Category create writes canonical audit row
do $$
declare
  v_admin uuid := 'a4200000-0000-4000-8000-000000000101';
  v_category uuid := '10000000-0000-4000-8000-000000000099';
  v_count integer;
  v_metadata jsonb;
begin
  perform pg_temp.aud_set_auth(v_admin);

  insert into public.categories (
    id, name, slug, sort_order, is_active
  ) values (
    v_category, 'Audit Test Category', 'audit-test-category', 999, true
  );

  select count(*)
  into v_count
  from public.cms_privileged_audit_events
  where entity_type = 'category'
    and entity_id = v_category
    and action = 'create';

  if v_count <> 1 then
    raise exception 'FAIL: expected one category create audit row';
  end if;

  select metadata
  into v_metadata
  from public.cms_privileged_audit_events
  where entity_type = 'category'
    and entity_id = v_category
    and action = 'create'
  limit 1;

  if v_metadata ? 'description'
     or v_metadata ? 'image_path'
     or v_metadata ? 'cost_price' then
    raise exception 'FAIL: category audit metadata contains disallowed keys';
  end if;

  perform pg_temp.aud_clear_auth();
end;
$$;

\echo 'PASS: category create audited'

-- Staff cannot list audit events; admin can
do $$
declare
  v_admin uuid := 'a4200000-0000-4000-8000-000000000101';
  v_staff uuid := 'a4200000-0000-4000-8000-000000000102';
  v_rows integer;
begin
  perform pg_temp.aud_set_auth(v_staff);
  begin
    perform *
    from public.list_cms_privileged_audit_events();
    raise exception 'FAIL: staff may execute list_cms_privileged_audit_events';
  exception
    when others then
      if sqlstate <> '42501' then
        raise;
      end if;
  end;
  perform pg_temp.aud_clear_auth();

  perform pg_temp.aud_set_auth(v_admin);
  select count(*) into v_rows
  from public.list_cms_privileged_audit_events();
  if v_rows < 1 then
    raise exception 'FAIL: admin audit RPC returned no rows';
  end if;
  perform pg_temp.aud_clear_auth();
end;
$$;

\echo 'PASS: admin-only audit RPC'

-- Staff management mirror excludes target_email
do $$
declare
  v_admin uuid := 'a4200000-0000-4000-8000-000000000101';
  v_staff uuid := 'a4200000-0000-4000-8000-000000000102';
  v_metadata jsonb;
begin
  perform pg_temp.aud_set_auth(v_admin);
  perform public.update_cms_staff(v_staff, null, false);
  perform pg_temp.aud_clear_auth();

  select metadata
  into v_metadata
  from public.cms_privileged_audit_events
  where entity_type = 'staff'
    and action = 'deactivate'
  order by occurred_at desc, id desc
  limit 1;

  if v_metadata is null then
    raise exception 'FAIL: staff deactivate audit row missing';
  end if;
  if v_metadata ? 'target_email' or v_metadata ? 'email' then
    raise exception 'FAIL: staff audit metadata leaked email';
  end if;
end;
$$;

\echo 'PASS: staff audit metadata sanitized'

-- UPDATE immutability
do $$
declare
  v_event uuid;
begin
  select id into v_event
  from public.cms_privileged_audit_events
  order by occurred_at desc, id desc
  limit 1;

  begin
    update public.cms_privileged_audit_events
    set action = 'delete'
    where id = v_event;
    raise exception 'FAIL: audit UPDATE succeeded';
  exception
    when others then
      if sqlstate <> '55000' then
        raise;
      end if;
  end;
end;
$$;

\echo 'PASS: audit immutability'

do $$
begin
  perform pg_temp.aud_cleanup_events();
end;
$$;

rollback;

\echo 'PASS: CMS privileged audit trail regression complete'
