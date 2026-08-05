#!/usr/bin/env bash
# Local-only runner for TASK-006 RLS / Storage / RPC regressions.
#
# Validates the target looks like the disposable local Supabase DB container,
# then executes 01_rls_checklist.sql with ON_ERROR_STOP.
#
# Usage:
#   bash supabase/tests/database/01_rls_checklist.sh
#   DB_CONTAINER=supabase_db_Badminton-Store bash supabase/tests/database/01_rls_checklist.sh
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-supabase_db_Badminton-Store}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SQL_FILE="${ROOT}/supabase/tests/database/01_rls_checklist.sql"

if [[ ! -f "$SQL_FILE" ]]; then
  echo "FAIL: missing SQL suite at ${SQL_FILE}" >&2
  exit 1
fi

if ! docker inspect "$DB_CONTAINER" >/dev/null 2>&1; then
  echo "FAIL: local DB container '${DB_CONTAINER}' not found" >&2
  exit 1
fi

# Refuse accidental non-local targets: name must look like supabase_db_* and
# the database must expose the application schema.
DB_NAME="$(
  docker inspect -f '{{.Name}}' "$DB_CONTAINER" 2>/dev/null | sed 's#^/##'
)"
if [[ "$DB_NAME" != supabase_db_* ]]; then
  echo "FAIL: container '${DB_NAME}' does not look like a local supabase_db_* target" >&2
  exit 1
fi

IMAGE="$(docker inspect -f '{{.Config.Image}}' "$DB_CONTAINER")"
case "$IMAGE" in
  *supabase/postgres*|*public.ecr.aws/supabase/postgres*) ;;
  *)
    echo "FAIL: container image does not look like supabase/postgres" >&2
    exit 1
    ;;
esac

echo "== TASK-006 RLS checklist via ${DB_NAME} =="
docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 <"$SQL_FILE"
echo "== TASK-006 runner done =="
