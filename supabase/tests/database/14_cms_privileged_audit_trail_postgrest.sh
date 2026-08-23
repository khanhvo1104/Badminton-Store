#!/usr/bin/env bash
# PostgREST service-role JWT regression: session_user stays authenticator, so
# setting app.cms_audit_internal and INSERT into cms_privileged_audit_events
# must fail even when the row satisfies metadata CHECK constraints.
#
# Requires supabase_admin (local superuser); the default postgres role cannot
# SET SESSION AUTHORIZATION. Prefer running after `supabase db reset`.
# Usage:
#   bash supabase/tests/database/14_cms_privileged_audit_trail_postgrest.sh
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-supabase_db_Badminton-Store}"
PSQL_ADMIN=(docker exec -i "$DB_CONTAINER" psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1)

ADMIN='a4200000-0000-4000-8000-000000000101'
CATEGORY='10000000-0000-4000-8000-000000000001'

echo "== CMS audit PostgREST service_role GUC INSERT boundary =="

"${PSQL_ADMIN[@]}" <<SQL
do \$\$
declare
  v_direct_denied boolean := false;
begin
  execute 'set session authorization authenticator';
  execute 'set local role service_role';
  perform set_config('app.cms_audit_internal', '1', true);

  begin
    insert into public.cms_privileged_audit_events (
      actor_id, entity_type, entity_id, action, metadata
    ) values (
      '${ADMIN}'::uuid,
      'category',
      '${CATEGORY}'::uuid,
      'create',
      jsonb_build_object(
        'slug', 'postgrest-forged',
        'name', 'PostgREST Forged',
        'is_active', true
      )
    );
  exception
    when insufficient_privilege then
      v_direct_denied := true;
    when others then
      if sqlstate = '42501' then
        v_direct_denied := true;
      else
        execute 'reset session authorization';
        raise;
      end if;
  end;

  if not v_direct_denied then
    execute 'reset session authorization';
    raise exception
      'FAIL: service_role GUC INSERT allowed under authenticator+service_role';
  end if;

  execute 'reset session authorization';
end;
\$\$;
SQL

echo "PASS: authenticator service_role audit GUC INSERT boundary"
echo "== CMS audit PostgREST service_role GUC INSERT boundary complete =="
