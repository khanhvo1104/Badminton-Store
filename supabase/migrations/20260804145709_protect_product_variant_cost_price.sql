-- Restrict public Data API projection of product_variants so cost_price is
-- not selectable by anon/authenticated (including Flutter staff/admin JWTs,
-- which share the PostgreSQL authenticated role with customers).
--
-- Column privileges address projection security. Existing RLS policies
-- product_variants_select_active_public and product_variants_staff_write are
-- intentionally left unchanged and continue to enforce row visibility.
-- service_role / database-owner access is not revoked or re-granted here.

revoke select on table public.product_variants from anon, authenticated;

grant select (
  id,
  product_id,
  sku,
  name,
  color_name,
  color_hex,
  racket_weight_class,
  grip_size,
  shoe_size,
  clothing_size,
  unit,
  price,
  compare_at_price,
  attributes,
  is_default,
  is_active,
  sort_order
) on table public.product_variants to anon, authenticated;
