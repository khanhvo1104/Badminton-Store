#!/usr/bin/env bash
# Two-session regression: concurrent primary switches must serialize and
# leave exactly one general primary for the product.
#
# Requires a migrated local Supabase DB. Prefer running after `supabase db reset`.
# Usage:
#   bash supabase/tests/database/10_cms_product_media_concurrency.sh
#   DB_CONTAINER=supabase_db_Badminton-Store bash ...
set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-supabase_db_Badminton-Store}"
PSQL=(docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1)

STAFF='a3850000-0000-4000-8000-000000000102'
CATEGORY='a3860000-0000-4000-8000-000000000101'
PRODUCT='a3870000-0000-4000-8000-000000000101'
IMAGE_A='a3880000-0000-4000-8000-000000000101'
IMAGE_B='a3880000-0000-4000-8000-000000000102'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== CMS product media primary concurrency =="

"${PSQL[@]}" <<SQL
delete from public.product_images where product_id = '${PRODUCT}';
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
  'media-race@example.invalid',
  crypt('media-race-password', gen_salt('bf')),
  timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  timezone('utc', now()),
  timezone('utc', now())
);

update public.profiles
set role = 'staff', full_name = 'Media Race Staff', is_active = true
where id = '${STAFF}';

insert into public.categories (id, name, slug, sort_order, is_active)
values ('${CATEGORY}', 'Media Race Category', 'media-race-category', 385, true);

insert into public.products (
  id, category_id, name, slug, status, is_featured, published_at
) values (
  '${PRODUCT}', '${CATEGORY}', 'Media Race Product', 'media-race-product',
  'draft', false, null
);

insert into public.product_images (
  id, product_id, variant_id, storage_path, alt_text, sort_order, is_primary
) values
  (
    '${IMAGE_A}', '${PRODUCT}', null,
    'product-images/${PRODUCT}/a.webp', 'A', 0, true
  ),
  (
    '${IMAGE_B}', '${PRODUCT}', null,
    'product-images/${PRODUCT}/b.webp', 'B', 1, false
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
select image_id
from public.set_cms_product_image_primary(
  '${PRODUCT}'::uuid,
  '${IMAGE_A}'::uuid
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
select image_id
from public.set_cms_product_image_primary(
  '${PRODUCT}'::uuid,
  '${IMAGE_B}'::uuid
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
  echo "FAIL: concurrent media primary sessions did not both succeed" >&2
  echo "--- session A ---" >&2
  cat "$TMP/a.out" "$TMP/a.err" >&2 || true
  echo "--- session B ---" >&2
  cat "$TMP/b.out" "$TMP/b.err" >&2 || true
  exit 1
fi

"${PSQL[@]}" <<SQL
do \$\$
declare
  v_primary_count integer;
  v_primary_id uuid;
begin
  select count(*)::integer
  into v_primary_count
  from public.product_images
  where product_id = '${PRODUCT}'
    and variant_id is null
    and is_primary = true;

  if v_primary_count <> 1 then
    raise exception
      'FAIL: concurrent primary switch left % primaries',
      v_primary_count;
  end if;

  select id
  into v_primary_id
  from public.product_images
  where product_id = '${PRODUCT}'
    and variant_id is null
    and is_primary = true;

  if v_primary_id not in ('${IMAGE_A}'::uuid, '${IMAGE_B}'::uuid) then
    raise exception 'FAIL: concurrent primary switch left unexpected id';
  end if;

  raise notice 'OK: concurrent product image primary switches serialized';
end;
\$\$;
SQL

echo "== CMS product media primary concurrency done =="

PRODUCT2='a3870000-0000-4000-8000-000000000201'
VARIANT2='a3870000-0000-4000-8000-000000000202'
IMAGE_X='a3880000-0000-4000-8000-000000000201'
IMAGE_Y='a3880000-0000-4000-8000-000000000202'
IMAGE_Z='a3880000-0000-4000-8000-000000000203'

echo "== CMS product media variant-move concurrency =="

"${PSQL[@]}" <<SQL
delete from public.product_images where product_id = '${PRODUCT2}';
delete from public.product_variants where product_id = '${PRODUCT2}';
delete from public.products where id = '${PRODUCT2}';

insert into public.products (
  id, category_id, name, slug, status, is_featured, published_at
) values (
  '${PRODUCT2}', '${CATEGORY}', 'Media Race Product 2', 'media-race-product-2',
  'draft', false, null
);

insert into public.product_variants (
  id, product_id, sku, name, price, is_default, is_active, sort_order
) values (
  '${VARIANT2}', '${PRODUCT2}', 'MEDIA-RACE-2', 'Race', 1000, true, true, 0
);

insert into public.product_images (
  id, product_id, variant_id, storage_path, alt_text, sort_order, is_primary
) values
  (
    '${IMAGE_X}', '${PRODUCT2}', null,
    'product-images/${PRODUCT2}/x.webp', 'X', 0, true
  ),
  (
    '${IMAGE_Y}', '${PRODUCT2}', null,
    'product-images/${PRODUCT2}/y.webp', 'Y', 1, false
  ),
  (
    '${IMAGE_Z}', '${PRODUCT2}', null,
    'product-images/${PRODUCT2}/z.webp', 'Z', 2, false
  );
SQL

cat >"$TMP/move_a.sql" <<SQL
begin;
select set_config('request.jwt.claim.sub', '${STAFF}', true);
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '${STAFF}', 'role', 'authenticated')::text,
  true
);
set local role authenticated;
select image_id
from public.update_cms_product_image(
  '${PRODUCT2}'::uuid,
  '${IMAGE_Y}'::uuid,
  'Y moved',
  '${VARIANT2}'::uuid,
  1
);
select pg_sleep(2);
commit;
SQL

cat >"$TMP/move_b.sql" <<SQL
begin;
select set_config('request.jwt.claim.sub', '${STAFF}', true);
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '${STAFF}', 'role', 'authenticated')::text,
  true
);
set local role authenticated;
select image_id
from public.update_cms_product_image(
  '${PRODUCT2}'::uuid,
  '${IMAGE_Z}'::uuid,
  'Z moved',
  '${VARIANT2}'::uuid,
  2
);
commit;
SQL

"${PSQL[@]}" -f /dev/stdin <"$TMP/move_a.sql" >"$TMP/ma.out" 2>"$TMP/ma.err" &
PID_MA=$!
sleep 0.4
"${PSQL[@]}" -f /dev/stdin <"$TMP/move_b.sql" >"$TMP/mb.out" 2>"$TMP/mb.err" &
PID_MB=$!

wait "$PID_MA"
STATUS_MA=$?
wait "$PID_MB"
STATUS_MB=$?

if [[ "$STATUS_MA" -ne 0 || "$STATUS_MB" -ne 0 ]]; then
  echo "FAIL: concurrent media update sessions did not both succeed" >&2
  echo "--- session A ---" >&2
  cat "$TMP/ma.out" "$TMP/ma.err" >&2 || true
  echo "--- session B ---" >&2
  cat "$TMP/mb.out" "$TMP/mb.err" >&2 || true
  exit 1
fi

"${PSQL[@]}" <<SQL
do \$\$
declare
  v_variant_primary integer;
  v_general_primary integer;
  v_moved integer;
begin
  select count(*)::integer
  into v_moved
  from public.product_images
  where product_id = '${PRODUCT2}'
    and variant_id = '${VARIANT2}';
  if v_moved <> 2 then
    raise exception 'FAIL: concurrent variant moves left % variant images', v_moved;
  end if;

  select count(*)::integer
  into v_variant_primary
  from public.product_images
  where variant_id = '${VARIANT2}'
    and is_primary = true;
  if v_variant_primary <> 1 then
    raise exception
      'FAIL: concurrent variant moves left % variant primaries',
      v_variant_primary;
  end if;

  select count(*)::integer
  into v_general_primary
  from public.product_images
  where product_id = '${PRODUCT2}'
    and variant_id is null
    and is_primary = true;
  if v_general_primary <> 1 then
    raise exception
      'FAIL: concurrent variant moves left % general primaries',
      v_general_primary;
  end if;

  raise notice 'OK: concurrent product image variant moves serialized';
end;
\$\$;
SQL

echo "== CMS product media variant-move concurrency done =="
