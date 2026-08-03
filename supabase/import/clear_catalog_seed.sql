-- WARNING: Deletes ONLY deterministic catalog seed rows created by
-- scripts/generate_catalog_seed.py (UUID ranges below).
-- Does NOT truncate tables. Does NOT delete customer/order data.
--
-- UUID ranges:
--   categories 10000000-%
--   brands     20000000-%
--   products   30000000-%
--   variants   40000000-%
--   images     50000000-%
--
-- Usage (local):
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
--     -f supabase/import/clear_catalog_seed.sql

begin;

delete from public.inventory i
using public.product_variants v
where i.variant_id = v.id
  and v.id::text like '40000000-%';

delete from public.product_images
where id::text like '50000000-%';

delete from public.product_variants
where id::text like '40000000-%';

delete from public.products
where id::text like '30000000-%';

delete from public.brands
where id::text like '20000000-%';

delete from public.categories
where id::text like '10000000-%';

commit;
