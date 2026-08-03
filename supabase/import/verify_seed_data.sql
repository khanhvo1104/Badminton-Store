-- Read-only validation for catalog seed (deterministic UUID ranges).
-- Usage (local):
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
--     -f supabase/import/verify_seed_data.sql

\echo '=== Catalog seed verification ==='

select 'categories' as metric, count(*)::text as value
from public.categories
where id::text like '10000000-%'
union all
select 'brands', count(*)::text
from public.brands
where id::text like '20000000-%'
union all
select 'products', count(*)::text
from public.products
where id::text like '30000000-%'
union all
select 'products_active', count(*)::text
from public.products
where id::text like '30000000-%' and status = 'active'
union all
select 'products_draft', count(*)::text
from public.products
where id::text like '30000000-%' and status = 'draft'
union all
select 'products_inactive', count(*)::text
from public.products
where id::text like '30000000-%' and status = 'inactive'
union all
select 'products_archived', count(*)::text
from public.products
where id::text like '30000000-%' and status = 'archived'
union all
select 'products_featured_active', count(*)::text
from public.products
where id::text like '30000000-%' and status = 'active' and is_featured
union all
select 'variants', count(*)::text
from public.product_variants
where id::text like '40000000-%'
union all
select 'variants_active', count(*)::text
from public.product_variants
where id::text like '40000000-%' and is_active
union all
select 'images', count(*)::text
from public.product_images
where id::text like '50000000-%'
union all
select 'inventory_rows', count(*)::text
from public.inventory i
join public.product_variants v on v.id = i.variant_id
where v.id::text like '40000000-%';

\echo '--- integrity checks (expect 0) ---'

select 'products_without_variants' as issue, count(*)::text as value
from public.products p
where p.id::text like '30000000-%'
  and not exists (
    select 1 from public.product_variants v where v.product_id = p.id
  )
union all
select 'products_without_default_variant', count(*)::text
from public.products p
where p.id::text like '30000000-%'
  and not exists (
    select 1 from public.product_variants v
    where v.product_id = p.id and v.is_default
  )
union all
select 'products_with_multiple_defaults', count(*)::text
from (
  select product_id
  from public.product_variants
  where id::text like '40000000-%' and is_default
  group by product_id
  having count(*) > 1
) t
union all
select 'products_without_images', count(*)::text
from public.products p
where p.id::text like '30000000-%'
  and not exists (
    select 1 from public.product_images i where i.product_id = p.id
  )
union all
select 'products_without_primary_general_image', count(*)::text
from public.products p
where p.id::text like '30000000-%'
  and not exists (
    select 1 from public.product_images i
    where i.product_id = p.id and i.is_primary and i.variant_id is null
  )
union all
select 'variants_without_inventory', count(*)::text
from public.product_variants v
where v.id::text like '40000000-%'
  and not exists (
    select 1 from public.inventory i where i.variant_id = v.id
  )
union all
select 'duplicate_skus', count(*)::text
from (
  select sku from public.product_variants
  where id::text like '40000000-%'
  group by sku having count(*) > 1
) t
union all
select 'duplicate_product_slugs', count(*)::text
from (
  select slug from public.products
  where id::text like '30000000-%'
  group by slug having count(*) > 1
) t
union all
select 'images_variant_product_mismatch', count(*)::text
from public.product_images i
join public.product_variants v on v.id = i.variant_id
where i.id::text like '50000000-%'
  and v.product_id <> i.product_id
union all
select 'invalid_compare_at_price', count(*)::text
from public.product_variants v
where v.id::text like '40000000-%'
  and v.compare_at_price is not null
  and v.compare_at_price < v.price
union all
select 'invalid_reserved_inventory', count(*)::text
from public.inventory i
join public.product_variants v on v.id = i.variant_id
where v.id::text like '40000000-%'
  and not i.allow_backorder
  and i.quantity_reserved > i.quantity_on_hand;

\echo '--- stock scenarios ---'

select 'low_stock_1_to_4' as metric, count(*)::text as value
from public.inventory i
join public.product_variants v on v.id = i.variant_id
where v.id::text like '40000000-%'
  and i.quantity_on_hand between 1 and 4
union all
select 'out_of_stock_no_backorder', count(*)::text
from public.inventory i
join public.product_variants v on v.id = i.variant_id
where v.id::text like '40000000-%'
  and i.quantity_on_hand = 0
  and not i.allow_backorder
union all
select 'backorder_enabled', count(*)::text
from public.inventory i
join public.product_variants v on v.id = i.variant_id
where v.id::text like '40000000-%'
  and i.allow_backorder;

\echo '=== done ==='
