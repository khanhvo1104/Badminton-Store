#!/usr/bin/env bash
# Two-session regression: concurrent transitions on the same order must
# serialize so only one succeeds and inventory is not double-mutated.
#
# Requires a migrated local Supabase DB. Prefer running after `supabase db reset`.
# Usage:
#   bash supabase/tests/database/11_cms_order_operations_concurrency.sh
#   DB_CONTAINER=supabase_db_Badminton-Store bash ...
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-supabase_db_Badminton-Store}"
PSQL=(docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1)

STAFF='b3950000-0000-4000-8000-000000000101'
CATEGORY='b3960000-0000-4000-8000-000000000101'
PRODUCT='b3970000-0000-4000-8000-000000000101'
VARIANT='b3980000-0000-4000-8000-000000000101'
ORDER_ID='b3990000-0000-4000-8000-000000000101'
CUSTOMER='b3950000-0000-4000-8000-000000000102'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== CMS order transition concurrency =="

"${PSQL[@]}" <<SQL
delete from public.order_status_history where order_id = '${ORDER_ID}';
delete from public.order_items where order_id = '${ORDER_ID}';
delete from public.orders where id = '${ORDER_ID}';
delete from public.inventory where variant_id = '${VARIANT}';
delete from public.product_variants where id = '${VARIANT}';
delete from public.products where id = '${PRODUCT}';
delete from public.categories where id = '${CATEGORY}';
delete from public.profiles where id in ('${STAFF}', '${CUSTOMER}');
delete from auth.users where id in ('${STAFF}', '${CUSTOMER}');

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
(
  '00000000-0000-0000-0000-000000000000',
  '${STAFF}',
  'authenticated',
  'authenticated',
  'orders-race-staff@example.invalid',
  crypt('orders-race-password', gen_salt('bf')),
  timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  timezone('utc', now()),
  timezone('utc', now())
),
(
  '00000000-0000-0000-0000-000000000000',
  '${CUSTOMER}',
  'authenticated',
  'authenticated',
  'orders-race-customer@example.invalid',
  crypt('orders-race-password', gen_salt('bf')),
  timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  timezone('utc', now()),
  timezone('utc', now())
);

update public.profiles
set role = 'staff', full_name = 'Orders Race Staff', is_active = true
where id = '${STAFF}';
update public.profiles
set role = 'customer', full_name = 'Orders Race Customer', is_active = true
where id = '${CUSTOMER}';

insert into public.categories (id, name, slug, sort_order, is_active)
values ('${CATEGORY}', 'Orders Race Category', 'orders-race-category', 395, true);

insert into public.products (
  id, category_id, name, slug, status, is_featured, published_at
) values (
  '${PRODUCT}', '${CATEGORY}', 'Orders Race Product', 'orders-race-product',
  'active', false, timezone('utc', now())
);

insert into public.product_variants (
  id, product_id, sku, name, price, is_default, is_active, sort_order
) values (
  '${VARIANT}', '${PRODUCT}', 'ORD-RACE-1', 'Race', 1000, true, true, 0
);

insert into public.inventory (
  variant_id, quantity_on_hand, quantity_reserved, reorder_level, allow_backorder
) values (
  '${VARIANT}', 10, 3, 0, false
);

insert into public.orders (
  id, order_number, user_id, status,
  subtotal, discount_total, shipping_fee, grand_total,
  recipient_name, recipient_phone, shipping_address
) values (
  '${ORDER_ID}', 'BDM-ORD-RACE-1', '${CUSTOMER}', 'confirmed',
  3000, 0, 0, 3000,
  'Race Recipient', '0909999999',
  '{"recipient_name":"Race Recipient"}'::jsonb
);

insert into public.order_items (
  order_id, product_id, variant_id, product_name, variant_name, sku,
  unit_price, quantity, line_total
) values (
  '${ORDER_ID}', '${PRODUCT}', '${VARIANT}', 'Orders Race Product', 'Race',
  'ORD-RACE-1', 1000, 3, 3000
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
select order_id
from public.transition_cms_order_status(
  '${ORDER_ID}'::uuid,
  'cancelled',
  'race-a'
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
select order_id
from public.transition_cms_order_status(
  '${ORDER_ID}'::uuid,
  'cancelled',
  'race-b'
);
commit;
SQL

"${PSQL[@]}" -f /dev/stdin <"$TMP/session_a.sql" >"$TMP/a.out" 2>"$TMP/a.err" &
PID_A=$!
sleep 0.4
"${PSQL[@]}" -f /dev/stdin <"$TMP/session_b.sql" >"$TMP/b.out" 2>"$TMP/b.err" &
PID_B=$!

set +e
wait "$PID_A"
STATUS_A=$?
wait "$PID_B"
STATUS_B=$?
set -e

SUCCESS_COUNT=0
if [[ "$STATUS_A" -eq 0 ]]; then
  SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
fi
if [[ "$STATUS_B" -eq 0 ]]; then
  SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
fi

if [[ "$SUCCESS_COUNT" -ne 1 ]]; then
  echo "FAIL: expected exactly one concurrent cancel to succeed" >&2
  echo "--- session A ($STATUS_A) ---" >&2
  cat "$TMP/a.out" "$TMP/a.err" >&2 || true
  echo "--- session B ($STATUS_B) ---" >&2
  cat "$TMP/b.out" "$TMP/b.err" >&2 || true
  exit 1
fi

"${PSQL[@]}" <<SQL
do \$\$
declare
  v_status text;
  v_reserved integer;
  v_history integer;
begin
  select status into v_status from public.orders where id = '${ORDER_ID}';
  if v_status is distinct from 'cancelled' then
    raise exception 'FAIL: concurrent cancel left status %', v_status;
  end if;

  select quantity_reserved into v_reserved
  from public.inventory where variant_id = '${VARIANT}';
  if v_reserved <> 0 then
    raise exception 'FAIL: concurrent cancel left reserved %', v_reserved;
  end if;

  select count(*) into v_history
  from public.order_status_history
  where order_id = '${ORDER_ID}'
    and from_status = 'confirmed'
    and to_status = 'cancelled';
  if v_history <> 1 then
    raise exception 'FAIL: concurrent cancel history count=%', v_history;
  end if;

  raise notice 'OK: concurrent order transitions serialized';
end;
\$\$;
SQL

echo "== CMS order transition concurrency done =="
