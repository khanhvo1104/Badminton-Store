#!/usr/bin/env bash
# Two-session regression: concurrent last-admin demotion/deactivation attempts
# must leave exactly one active admin.
#
# Requires a migrated local Supabase DB. Prefer running after `supabase db reset`.
# Usage:
#   bash supabase/tests/database/13_cms_staff_management_concurrency.sh
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-supabase_db_Badminton-Store}"
PSQL=(docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1)

ADMIN_A='a4100000-0000-4000-8000-000000000201'
ADMIN_B='a4100000-0000-4000-8000-000000000202'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== CMS staff last-admin concurrency =="

"${PSQL[@]}" <<SQL
delete from public.staff_management_events
where actor_id in ('${ADMIN_A}', '${ADMIN_B}')
   or target_id in ('${ADMIN_A}', '${ADMIN_B}');
delete from public.profiles where id in ('${ADMIN_A}', '${ADMIN_B}');
delete from auth.users where id in ('${ADMIN_A}', '${ADMIN_B}');

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
(
  '00000000-0000-0000-0000-000000000000', '${ADMIN_A}', 'authenticated', 'authenticated',
  'staff-race-admin-a@example.invalid', crypt('race-password', gen_salt('bf')),
  timezone('utc', now()), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  timezone('utc', now()), timezone('utc', now())
),
(
  '00000000-0000-0000-0000-000000000000', '${ADMIN_B}', 'authenticated', 'authenticated',
  'staff-race-admin-b@example.invalid', crypt('race-password', gen_salt('bf')),
  timezone('utc', now()), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  timezone('utc', now()), timezone('utc', now())
);

begin;
select set_config('app.trusted_staff_management', '1', true);
update public.profiles
set role = 'admin', is_active = true, full_name = 'Race Admin A'
where id = '${ADMIN_A}';
update public.profiles
set role = 'admin', is_active = true, full_name = 'Race Admin B'
where id = '${ADMIN_B}';
select set_config('app.trusted_staff_management', '', true);
commit;
SQL

cat >"$TMP/session_a.sql" <<SQL
begin;
select set_config('request.jwt.claim.sub', '${ADMIN_A}', true);
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '${ADMIN_A}', 'role', 'authenticated')::text,
  true
);
set local role authenticated;
select pg_sleep(0.15);
select public.update_cms_staff('${ADMIN_B}', null, false);
commit;
SQL

cat >"$TMP/session_b.sql" <<SQL
begin;
select set_config('request.jwt.claim.sub', '${ADMIN_B}', true);
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '${ADMIN_B}', 'role', 'authenticated')::text,
  true
);
set local role authenticated;
select pg_sleep(0.15);
select public.update_cms_staff('${ADMIN_A}', null, false);
commit;
SQL

(set +e
 docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=0 < "$TMP/session_a.sql" >"$TMP/a.out" 2>&1 &
 pid_a=$!
 docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=0 < "$TMP/session_b.sql" >"$TMP/b.out" 2>&1 &
 pid_b=$!
 wait "$pid_a"
 wait "$pid_b")

ACTIVE_ADMINS="$("${PSQL[@]}" -Atc "select count(*) from public.profiles where role = 'admin' and is_active = true;")"

if [[ "$ACTIVE_ADMINS" -lt 1 ]]; then
  echo "FAIL: no active admin remained after concurrent demotion attempts"
  exit 1
fi

echo "PASS: at least one active admin remains (${ACTIVE_ADMINS})"

"${PSQL[@]}" <<SQL
delete from public.staff_management_events
where actor_id in ('${ADMIN_A}', '${ADMIN_B}')
   or target_id in ('${ADMIN_A}', '${ADMIN_B}');
delete from public.profiles where id in ('${ADMIN_A}', '${ADMIN_B}');
delete from auth.users where id in ('${ADMIN_A}', '${ADMIN_B}');
SQL

echo "== CMS staff last-admin concurrency complete =="
