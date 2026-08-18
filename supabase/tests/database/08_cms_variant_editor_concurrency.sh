#!/usr/bin/env bash
# Two-session regression: concurrent default switches must serialize and leave
# exactly one default variant per product.
#
# Requires a migrated local Supabase DB. Prefer running after `supabase db reset`.
# Usage:
#   bash supabase/tests/database/08_cms_variant_editor_concurrency.sh
#   DB_CONTAINER=supabase_db_Badminton-Store bash ...
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-supabase_db_Badminton-Store}"
PSQL=(docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1)

STAFF='a3600000-0000-4000-8000-000000000102'
PRODUCT='a3620000-0000-4000-8000-000000000101'
VARIANT_A='a3630000-0000-4000-8000-000000000101'
VARIANT_B='a3630000-0000-4000-8000-000000000102'
CATEGORY='a3610000-0000-4000-8000-000000000101'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== CMS variant editor default-switch concurrency =="

"${PSQL[@]}" <<SQL
delete from public.product_variants where product_id = '${PRODUCT}';
delete from public.products where id = '${PRODUCT}';
delete from public.categories where id = '${CATEGORY}';
delete from public.profiles where id = '${STAFF}';
delete from auth.users where id = '${STAFF}';

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '${STAFF}',
  'authenticated',
  'authenticated',
  'variant-editor-race@example.invalid',
  crypt('variant-editor-race-password', gen_salt('bf')),
  timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  timezone('utc', now()),
  timezone('utc', now())
);

update public.profiles
set role = 'staff', full_name = 'Variant Race Staff', is_active = true
where id = '${STAFF}';

insert into public.categories (id, name, slug, sort_order, is_active)
values ('${CATEGORY}', 'Variant Race Category', 'variant-race-category', 361, true);

insert into public.products (
  id, category_id, name, slug, status, is_featured, published_at
) values (
  '${PRODUCT}', '${CATEGORY}', 'Variant Race Product', 'variant-race-product',
  'draft', false, null
);

insert into public.product_variants (
  id, product_id, sku, name, price, is_default, is_active, sort_order
) values
  ('${VARIANT_A}', '${PRODUCT}', 'VE-RACE-A', 'A', 1000, true, true, 0),
  ('${VARIANT_B}', '${PRODUCT}', 'VE-RACE-B', 'B', 1100, false, true, 1);
SQL

cat >"$TMP/session_a.sql" <<SQL
begin;
select set_config('request.jwt.claim.sub', '${STAFF}', true);
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '${STAFF}', 'role', 'authenticated')::text,
  true
);
set local role authenticated;
select variant_id
from public.save_cms_product_variant(
  '${PRODUCT}'::uuid,
  '${VARIANT_A}'::uuid,
  'VE-RACE-A',
  'A',
  null, null, null, null, null, null,
  'item',
  1000,
  null,
  'unchanged',
  null,
  'unchanged',
  null,
  '{}'::jsonb,
  true,
  true,
  0
);
select pg_sleep(2);
commit;
SQL

cat >"$TMP/session_b.sql" <<SQL
begin;
select set_config('request.jwt.claim.sub', '${STAFF}', true);
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '${STAFF}', 'role', 'authenticated')::text,
  true
);
set local role authenticated;
select variant_id
from public.save_cms_product_variant(
  '${PRODUCT}'::uuid,
  '${VARIANT_B}'::uuid,
  'VE-RACE-B',
  'B',
  null, null, null, null, null, null,
  'item',
  1100,
  null,
  'unchanged',
  null,
  'unchanged',
  null,
  '{}'::jsonb,
  true,
  true,
  1
);
commit;
SQL

"${PSQL[@]}" -f /dev/stdin <"$TMP/session_a.sql" >"$TMP/a.out" 2>"$TMP/a.err" &
PID_A=$!
sleep 0.4
"${PSQL[@]}" -f /dev/stdin <"$TMP/session_b.sql" >"$TMP/b.out" 2>"$TMP/b.err" &
PID_B=$!

wait "$PID_A"
STATUS_A=$?
wait "$PID_B"
STATUS_B=$?

if [[ "$STATUS_A" -ne 0 || "$STATUS_B" -ne 0 ]]; then
  echo "FAIL: concurrent save sessions did not both succeed" >&2
  echo "--- session A ---" >&2
  cat "$TMP/a.out" "$TMP/a.err" >&2 || true
  echo "--- session B ---" >&2
  cat "$TMP/b.out" "$TMP/b.err" >&2 || true
  exit 1
fi

"${PSQL[@]}" <<SQL
do \$\$
declare
  v_defaults integer;
begin
  select count(*) into v_defaults
  from public.product_variants
  where product_id = '${PRODUCT}'
    and is_default = true;
  if v_defaults <> 1 then
    raise exception 'FAIL: concurrent default switch left % defaults', v_defaults;
  end if;
  raise notice 'OK: concurrent default switch serialized';
end;
\$\$;
SQL

echo "== CMS variant editor concurrency done =="
