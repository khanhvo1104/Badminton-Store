#!/usr/bin/env bash
# Two-session regression: concurrent inventory adjustments must serialize,
# preserve on-hand, and write one history row per successful call.
#
# Requires a migrated local Supabase DB. Prefer running after `supabase db reset`.
# Usage:
#   bash supabase/tests/database/09_cms_inventory_adjustments_concurrency.sh
#   DB_CONTAINER=supabase_db_Badminton-Store bash ...
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-supabase_db_Badminton-Store}"
PSQL=(docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1)

STAFF='a3700000-0000-4000-8000-000000000102'
CATEGORY='a3710000-0000-4000-8000-000000000101'
PRODUCT='a3720000-0000-4000-8000-000000000101'
VARIANT='a3730000-0000-4000-8000-000000000101'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== CMS inventory adjustment concurrency =="

"${PSQL[@]}" <<SQL
delete from public.inventory_history where variant_id = '${VARIANT}';
delete from public.inventory where variant_id = '${VARIANT}';
delete from public.product_variants where id = '${VARIANT}';
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
  'inventory-race@example.invalid',
  crypt('inventory-race-password', gen_salt('bf')),
  timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  timezone('utc', now()),
  timezone('utc', now())
);

update public.profiles
set role = 'staff', full_name = 'Inventory Race Staff', is_active = true
where id = '${STAFF}';

insert into public.categories (id, name, slug, sort_order, is_active)
values ('${CATEGORY}', 'Inventory Race Category', 'inventory-race-category', 371, true);

insert into public.products (
  id, category_id, name, slug, status, is_featured, published_at
) values (
  '${PRODUCT}', '${CATEGORY}', 'Inventory Race Product', 'inventory-race-product',
  'draft', false, null
);

insert into public.product_variants (
  id, product_id, sku, name, price, is_default, is_active, sort_order
) values (
  '${VARIANT}', '${PRODUCT}', 'INV-RACE-1', 'Race', 1000, true, true, 0
);

insert into public.inventory (
  variant_id, quantity_on_hand, quantity_reserved, reorder_level, allow_backorder
) values (
  '${VARIANT}', 10, 0, 0, false
);
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
select variant_id, quantity_on_hand
from public.adjust_cms_inventory(
  '${VARIANT}'::uuid,
  'add_stock',
  1,
  null,
  'received',
  null
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
select variant_id, quantity_on_hand
from public.adjust_cms_inventory(
  '${VARIANT}'::uuid,
  'add_stock',
  1,
  null,
  'received',
  null
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
  echo "FAIL: concurrent inventory sessions did not both succeed" >&2
  echo "--- session A ---" >&2
  cat "$TMP/a.out" "$TMP/a.err" >&2 || true
  echo "--- session B ---" >&2
  cat "$TMP/b.out" "$TMP/b.err" >&2 || true
  exit 1
fi

"${PSQL[@]}" <<SQL
do \$\$
declare
  v_on_hand integer;
  v_history integer;
begin
  select quantity_on_hand into v_on_hand
  from public.inventory
  where variant_id = '${VARIANT}';
  if v_on_hand <> 12 then
    raise exception 'FAIL: concurrent add_stock left on-hand %', v_on_hand;
  end if;

  select count(*) into v_history
  from public.inventory_history
  where variant_id = '${VARIANT}'
    and operation = 'add_stock'
    and quantity_on_hand_after = quantity_on_hand_before + 1;
  if v_history <> 2 then
    raise exception 'FAIL: concurrent add_stock history count=%', v_history;
  end if;

  raise notice 'OK: concurrent inventory adjustments serialized';
end;
\$\$;
SQL

echo "== CMS inventory adjustment concurrency done =="
