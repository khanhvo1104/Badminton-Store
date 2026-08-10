#!/usr/bin/env bash
# Two-session regression: concurrent cart_items INSERT vs checkout_cod must not
# append a phantom line to a converted cart.
#
# Requires a migrated local Supabase DB. Prefer running after `supabase db reset`.
# Usage:
#   bash supabase/tests/database/03_trusted_cod_checkout_concurrency.sh
#   DB_CONTAINER=supabase_db_Badminton-Store bash ...
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-supabase_db_Badminton-Store}"
PSQL=(docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1)

BUYER='c1000000-0000-4000-8000-000000000001'
ADDRESS='c2000000-0000-4000-8000-000000000001'
CART='c3000000-0000-4000-8000-000000000001'
VARIANT_A='40000000-0000-4000-8000-000000000001'
VARIANT_B='40000000-0000-4000-8000-000000000042'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== trusted COD checkout concurrency =="

"${PSQL[@]}" <<SQL
-- Clean prior fixture if re-run without reset.
delete from public.order_items
where order_id in (select id from public.orders where user_id = '${BUYER}');
delete from public.order_status_history
where order_id in (select id from public.orders where user_id = '${BUYER}');
delete from public.orders where user_id = '${BUYER}';
delete from public.cart_items where cart_id = '${CART}';
delete from public.carts where id = '${CART}';
delete from public.addresses where id = '${ADDRESS}';
delete from public.profiles where id = '${BUYER}';
delete from auth.users where id = '${BUYER}';

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '${BUYER}',
  'authenticated',
  'authenticated',
  'checkout-race@example.invalid',
  crypt('checkout-race-password', gen_salt('bf')),
  timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  timezone('utc', now()),
  timezone('utc', now())
);

insert into public.addresses (
  id, user_id, recipient_name, phone_number,
  province_name, district_name, ward_name, street_address, is_default
) values (
  '${ADDRESS}',
  '${BUYER}',
  'Race Buyer',
  '0901888888',
  'TP Hồ Chí Minh',
  'Quận 1',
  'Phường Bến Nghé',
  '88 Race Street',
  true
);

insert into public.carts (id, user_id, status, currency_code)
values ('${CART}', '${BUYER}', 'active', 'VND');

insert into public.cart_items (cart_id, variant_id, quantity)
values ('${CART}', '${VARIANT_A}', 1);
SQL

cat >"$TMP/session_a.sql" <<SQL
begin;
select set_config('request.jwt.claim.sub', '${BUYER}', true);
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '${BUYER}', 'role', 'authenticated')::text,
  true
);
set local role authenticated;

-- Hold the cart lock the same way checkout_cod does, then sleep so session B
-- can start an INSERT that blocks on the parent cart row.
select c.id
from public.carts c
where c.id = '${CART}'
for update of c;

select pg_sleep(2);

select public.checkout_cod('${ADDRESS}', 'concurrency-a') as order_id;
commit;
SQL

cat >"$TMP/session_b.sql" <<SQL
select pg_sleep(0.3);
begin;
select set_config('request.jwt.claim.sub', '${BUYER}', true);
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '${BUYER}', 'role', 'authenticated')::text,
  true
);
set local role authenticated;

insert into public.cart_items (cart_id, variant_id, quantity)
values ('${CART}', '${VARIANT_B}', 1);

commit;
SQL

set +e
"${PSQL[@]}" -f - <"$TMP/session_a.sql" >"$TMP/a.out" 2>&1 &
PID_A=$!
"${PSQL[@]}" -f - <"$TMP/session_b.sql" >"$TMP/b.out" 2>&1 &
PID_B=$!
wait "$PID_A"
EC_A=$?
wait "$PID_B"
EC_B=$?
set -e

echo "---- session A (checkout) exit=${EC_A} ----"
cat "$TMP/a.out"
echo "---- session B (insert) exit=${EC_B} ----"
cat "$TMP/b.out"

if [[ "$EC_A" -ne 0 ]]; then
  echo "FAIL: checkout session did not succeed"
  exit 1
fi

if [[ "$EC_B" -eq 0 ]]; then
  echo "FAIL: concurrent cart_items INSERT succeeded after/during checkout"
  exit 1
fi

if ! grep -Eqi 'active cart|require an active cart' "$TMP/b.out"; then
  echo "FAIL: concurrent INSERT did not fail with active-cart enforcement"
  exit 1
fi

"${PSQL[@]}" <<SQL
do \$\$
declare
  v_status text;
  v_item_count integer;
  v_order_count integer;
  v_order_item_count integer;
begin
  select status into v_status from public.carts where id = '${CART}';
  if v_status is distinct from 'converted' then
    raise exception 'FAIL: expected converted cart, got %', v_status;
  end if;

  select count(*)::integer into v_item_count
  from public.cart_items where cart_id = '${CART}';
  if v_item_count <> 1 then
    raise exception
      'FAIL: phantom cart_items present on converted cart (count=%)',
      v_item_count;
  end if;

  select count(*)::integer into v_order_count
  from public.orders where user_id = '${BUYER}';
  if v_order_count <> 1 then
    raise exception 'FAIL: expected exactly one order, got %', v_order_count;
  end if;

  select count(*)::integer into v_order_item_count
  from public.order_items oi
  join public.orders o on o.id = oi.order_id
  where o.user_id = '${BUYER}';
  if v_order_item_count <> 1 then
    raise exception
      'FAIL: expected exactly one order_item, got %',
      v_order_item_count;
  end if;

  raise notice 'OK: concurrent insert rejected; converted cart has no phantom line';
end \$\$;
SQL

# Leave DB tidy for subsequent suite runs.
"${PSQL[@]}" <<SQL
delete from public.order_items
where order_id in (select id from public.orders where user_id = '${BUYER}');
delete from public.order_status_history
where order_id in (select id from public.orders where user_id = '${BUYER}');
delete from public.orders where user_id = '${BUYER}';
delete from public.cart_items where cart_id = '${CART}';
delete from public.carts where id = '${CART}';
delete from public.addresses where id = '${ADDRESS}';
delete from public.profiles where id = '${BUYER}';
delete from auth.users where id = '${BUYER}';
SQL

echo "== concurrency done =="
