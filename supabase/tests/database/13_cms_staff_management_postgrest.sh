#!/usr/bin/env bash
# PostgREST service-role JWT regression: session_user stays authenticator, so
# direct profile mutation must fail and invitation finalization must use the
# trusted finalize_cms_staff_invitation RPC (service_role EXECUTE only).
#
# Requires supabase_admin (local superuser); the default postgres role cannot
# SET SESSION AUTHORIZATION. Prefer running after `supabase db reset`.
# Usage:
#   bash supabase/tests/database/13_cms_staff_management_postgrest.sh
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-supabase_db_Badminton-Store}"
PSQL=(docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1)
PSQL_ADMIN=(docker exec -i "$DB_CONTAINER" psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1)

ADMIN_A='a4100000-0000-4000-8000-000000000301'
INVITEE='a4100000-0000-4000-8000-000000000302'

echo "== CMS staff PostgREST invitation finalize boundary =="

"${PSQL[@]}" <<SQL
delete from public.staff_management_events
where actor_id = '${ADMIN_A}' and target_id = '${INVITEE}';
delete from public.profiles where id in ('${ADMIN_A}', '${INVITEE}');
delete from auth.users where id in ('${ADMIN_A}', '${INVITEE}');

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
(
  '00000000-0000-0000-0000-000000000000', '${ADMIN_A}', 'authenticated', 'authenticated',
  'staff-postgrest-admin@example.invalid', crypt('postgrest-password', gen_salt('bf')),
  timezone('utc', now()), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  timezone('utc', now()), timezone('utc', now())
),
(
  '00000000-0000-0000-0000-000000000000', '${INVITEE}', 'authenticated', 'authenticated',
  'staff-postgrest-invitee@example.invalid', crypt('postgrest-password', gen_salt('bf')),
  timezone('utc', now()), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  timezone('utc', now()), timezone('utc', now())
);

select set_config('app.trusted_staff_management', '1', true);
update public.profiles
set role = 'admin', is_active = true, full_name = 'PostgREST Admin'
where id = '${ADMIN_A}';
update public.profiles
set role = 'customer', is_active = true, full_name = 'PostgREST Invitee'
where id = '${INVITEE}';
select set_config('app.trusted_staff_management', '', true);
SQL

"${PSQL_ADMIN[@]}" <<SQL
do \$\$
declare
  v_result uuid;
  v_direct_denied boolean := false;
  v_events integer;
begin
  execute 'set session authorization authenticator';
  execute 'set local role service_role';

  begin
    update public.profiles
    set role = 'staff', is_active = true
    where id = '${INVITEE}';
  exception
    when others then
      if sqlstate = '42501' and sqlerrm = 'not authorized' then
        v_direct_denied := true;
      else
        execute 'reset session authorization';
        raise;
      end if;
  end;

  if not v_direct_denied then
    execute 'reset session authorization';
    raise exception
      'FAIL: direct profile mutation allowed under authenticator+service_role';
  end if;

  v_result := public.finalize_cms_staff_invitation(
    '${ADMIN_A}',
    '${INVITEE}',
    'staff',
    'staff-postgrest-invitee@example.invalid',
    'PostgREST Invitee'
  );

  if v_result <> '${INVITEE}'::uuid then
    execute 'reset session authorization';
    raise exception 'FAIL: finalize_cms_staff_invitation returned unexpected id';
  end if;

  select count(*)::integer into v_events
  from public.staff_management_events
  where actor_id = '${ADMIN_A}'::uuid
    and target_id = '${INVITEE}'::uuid
    and action = 'invite';

  if v_events <> 1 then
    execute 'reset session authorization';
    raise exception 'FAIL: expected one invite audit row after finalize RPC';
  end if;

  execute 'reset session authorization';
end;
\$\$;
SQL

"${PSQL[@]}" <<SQL
delete from public.staff_management_events
where actor_id = '${ADMIN_A}' and target_id = '${INVITEE}';
delete from public.profiles where id in ('${ADMIN_A}', '${INVITEE}');
delete from auth.users where id in ('${ADMIN_A}', '${INVITEE}');
SQL

echo "PASS: authenticator service_role invitation finalize boundary"
echo "== CMS staff PostgREST invitation finalize boundary complete =="
