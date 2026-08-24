#!/usr/bin/env bash
# Local-only CMS backup/restore verification rehearsal.
#
# Verifies that the documented logical dump procedure can produce a nonempty
# usable artifact from the disposable local Supabase/Postgres stack, restore it
# into an isolated temporary database inside that same local stack, and validate
# representative schema/data. Never operates on a linked/remote project.
#
# Usage (repo root, after `supabase start` + `supabase db reset --yes`):
#   bash scripts/cms-backup-rehearsal.sh
#
# Residual gap (honest): this rehearsal does not exercise hosted physical
# backups, PITR (`supabase backups restore`), Storage object restore, or a
# fully identical Auth/GoTrue catalog beyond a minimal local auth stub required
# for public-schema FK restore. Those remain human-operated quarterly drills
# against a separate non-production project.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

WORK_DIR=""
RESTORE_DB="cms_backup_rehearsal_$$"
DB_CONTAINER=""
FAILED=0

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  FAILED=1
  exit 1
}

cleanup() {
  local exit_code=$?
  if [[ -n "${DB_CONTAINER}" && -n "${RESTORE_DB}" ]]; then
    docker exec "${DB_CONTAINER}" \
      psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
      -c "DROP DATABASE IF EXISTS \"${RESTORE_DB}\" WITH (FORCE);" \
      >/dev/null 2>&1 || true
  fi
  if [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" ]]; then
    rm -rf "${WORK_DIR}"
  fi
  if [[ "${FAILED}" -ne 0 || "${exit_code}" -ne 0 ]]; then
    log "Backup rehearsal cleaned up after failure."
  else
    log "Backup rehearsal cleaned up successfully."
  fi
}

trap cleanup EXIT

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

# Fail closed: never call `supabase status` (any format) — its output includes
# service-role/secret values. Local-only guarantees come from: no args,
# unique supabase_db_* container, and explicit `supabase db dump --local`.
resolve_local_db_container() {
  docker ps --format '{{.Names}}' | python3 -c '
import sys
names = [line.strip() for line in sys.stdin if line.strip()]
matches = [name for name in names if name.startswith("supabase_db_")]
if len(matches) != 1:
    raise SystemExit(1)
print(matches[0])
'
}

assert_local_db_container() {
  local name="$1"
  local image
  local network_mode

  case "${name}" in
    supabase_db_*)
      ;;
    *)
      fail "Refusing unexpected database container name."
      ;;
  esac

  image="$(docker inspect -f '{{.Config.Image}}' "${name}" 2>/dev/null)" \
    || fail "Could not inspect local supabase_db_* container."
  case "$(printf '%s' "${image}" | tr '[:upper:]' '[:lower:]')" in
    *supabase*postgres*|*postgres*)
      ;;
    *)
      fail "Refusing non-Postgres image for supabase_db_* container."
      ;;
  esac

  network_mode="$(docker inspect -f '{{.HostConfig.NetworkMode}}' "${name}" 2>/dev/null)" \
    || fail "Could not inspect local supabase_db_* network mode."
  case "$(printf '%s' "${network_mode}" | tr '[:upper:]' '[:lower:]')" in
    *host*)
      fail "Refusing host-networked database container."
      ;;
  esac

  docker exec "${name}" \
    psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
    -c "SELECT 1;" \
    >/dev/null \
    || fail "Local supabase_db_* container is not accepting connections. Start it with: supabase start"
}

if [[ "${#}" -gt 0 ]]; then
  fail "This rehearsal accepts no arguments (refuse --linked/--db-url)."
fi

require_cmd supabase
require_cmd docker
require_cmd python3

if [[ -e "${ROOT_DIR}/supabase/.temp/project-ref" ]]; then
  log "Note: supabase/.temp/project-ref exists; rehearsal still forces --local only."
fi

log "Identifying unique local supabase_db_* container (no status/env key capture)..."
DB_CONTAINER="$(resolve_local_db_container)" \
  || fail "Could not uniquely identify local supabase_db_* container. Start local stack with: supabase start"
assert_local_db_container "${DB_CONTAINER}"
log "Using local container ${DB_CONTAINER}."

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cms-backup-rehearsal.XXXXXX")"
SCHEMA_DUMP="${WORK_DIR}/schema.sql"
DATA_DUMP="${WORK_DIR}/data.sql"
chmod 700 "${WORK_DIR}"

log "Creating local logical schema dump (--local, public schema)..."
supabase db dump --local --schema public -f "${SCHEMA_DUMP}" \
  >/dev/null || fail "Local schema dump failed (ensure disposable local stack is running)."

log "Creating local logical data dump (--local, public schema)..."
supabase db dump --local --data-only --use-copy --schema public -f "${DATA_DUMP}" \
  >/dev/null || fail "Local data dump failed (ensure disposable local stack is running)."

[[ -s "${SCHEMA_DUMP}" ]] || fail "Schema dump is empty."
[[ -s "${DATA_DUMP}" ]] || fail "Data dump is empty."

python3 - "${SCHEMA_DUMP}" "${DATA_DUMP}" <<'PY'
import pathlib
import sys

schema = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
data = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8", errors="replace")

required = ("products", "profiles", "orders")
for table in required:
    token = f'CREATE TABLE IF NOT EXISTS "public"."{table}"'
    alt = f'CREATE TABLE "public"."{table}"'
    if token not in schema and alt not in schema:
        raise SystemExit(f"Schema dump missing representative table: {table}")

if 'COPY "public"."products"' not in data and "COPY public.products" not in data:
    raise SystemExit("Data dump missing products COPY section.")

combined = (schema + data).lower()
for token in ("supabase.co", "pooler.supabase.com"):
    if token in combined:
        raise SystemExit(f"Dump unexpectedly references hosted host token: {token}")

print("Structural dump verification passed.")
PY

log "Creating isolated restore database ${RESTORE_DB} in local Supabase Postgres..."
docker exec "${DB_CONTAINER}" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS \"${RESTORE_DB}\" WITH (FORCE);" \
  >/dev/null
docker exec "${DB_CONTAINER}" \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  -c "CREATE DATABASE \"${RESTORE_DB}\";" \
  >/dev/null

log "Installing minimal local auth stub required for public.profiles FK..."
docker exec -i "${DB_CONTAINER}" \
  psql -U postgres -d "${RESTORE_DB}" -v ON_ERROR_STOP=1 >/dev/null <<'SQL'
CREATE SCHEMA IF NOT EXISTS auth;
CREATE TABLE IF NOT EXISTS auth.users (
  instance_id uuid NULL,
  id uuid PRIMARY KEY,
  email text NULL
);
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid
  LANGUAGE sql
  STABLE
  AS $$ SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
SQL

log "Restoring schema into isolated target..."
docker exec -i "${DB_CONTAINER}" \
  psql -U postgres -d "${RESTORE_DB}" -v ON_ERROR_STOP=1 \
  < "${SCHEMA_DUMP}" >/dev/null \
  || fail "Schema restore failed."

log "Restoring data into isolated target (session_replication_role=replica for circular FKs)..."
{
  printf '%s\n' "SET session_replication_role = replica;"
  cat "${DATA_DUMP}"
  printf '%s\n' "SET session_replication_role = DEFAULT;"
} | docker exec -i "${DB_CONTAINER}" \
  psql -U postgres -d "${RESTORE_DB}" -v ON_ERROR_STOP=1 \
  >/dev/null \
  || fail "Data restore failed."

log "Validating representative restored schema/data..."
PRODUCT_COUNT="$(
  docker exec -i "${DB_CONTAINER}" \
    psql -U postgres -d "${RESTORE_DB}" -v ON_ERROR_STOP=1 -At <<'SQL'
SELECT CASE WHEN to_regclass('public.products') IS NULL THEN -1 ELSE (SELECT count(*)::int FROM public.products) END;
SELECT CASE WHEN to_regclass('public.profiles') IS NULL THEN -1 ELSE 1 END;
SELECT CASE WHEN to_regclass('public.orders') IS NULL THEN -1 ELSE 1 END;
SQL
)"

python3 -c '
import sys
lines=[line.strip() for line in sys.argv[1].splitlines() if line.strip()]
if len(lines) != 3:
    raise SystemExit("Unexpected validation output.")
products=int(lines[0]); profiles_ok=int(lines[1]); orders_ok=int(lines[2])
if products < 1:
    raise SystemExit("Restored products table missing or empty.")
if profiles_ok != 1 or orders_ok != 1:
    raise SystemExit("Restored profiles/orders relation missing.")
print(f"Restored validation passed (products={products}).")
' "${PRODUCT_COUNT}"

log "Backup/restore rehearsal passed (local logical dump + isolated restore)."
log "Residual gap: hosted PITR/physical backup and Storage-object restore are not covered here."
exit 0
