-- Explicit least-privilege Data API grants for Supabase CLI 2.111+ defaults.
--
-- Fresh projects no longer inherit blanket table privileges for anon /
-- authenticated. This migration enumerates the intended grant matrix so
-- clients reach existing RLS policies instead of failing at the grant layer.
--
-- Customers, staff, and admins all use PostgreSQL role `authenticated`.
-- Operation grants therefore permit staff workflows; RLS predicates using
-- trusted public.profiles.role distinguish staff/admin from customers.
--
-- Preserves TASK-002 cost_price column restriction and TASK-004/007 function
-- contracts. Does not use ALTER DEFAULT PRIVILEGES or GRANT ON ALL.

-- ---------------------------------------------------------------------------
-- product_catalog.has_stock must not require raw inventory SELECT.
-- Public stock remains via get_variant_availability (SECURITY DEFINER).
-- ---------------------------------------------------------------------------
create or replace view public.product_catalog
with (security_invoker = true)
as
select
  p.id,
  p.name,
  p.slug,
  p.short_description,
  p.is_featured,
  p.published_at,
  c.id as category_id,
  c.name as category_name,
  c.slug as category_slug,
  b.id as brand_id,
  b.name as brand_name,
  b.slug as brand_slug,
  (
    select pi.storage_path
    from public.product_images pi
    where pi.product_id = p.id
      and pi.variant_id is null
      and pi.is_primary = true
    order by pi.sort_order
    limit 1
  ) as primary_image_path,
  (
    select min(pv.price)
    from public.product_variants pv
    where pv.product_id = p.id
      and pv.is_active = true
  ) as min_price,
  (
    select max(pv.price)
    from public.product_variants pv
    where pv.product_id = p.id
      and pv.is_active = true
  ) as max_price,
  (
    select min(pv.compare_at_price)
    from public.product_variants pv
    where pv.product_id = p.id
      and pv.is_active = true
      and pv.compare_at_price is not null
  ) as min_compare_at_price,
  (
    select count(*)::integer
    from public.product_variants pv
    where pv.product_id = p.id
      and pv.is_active = true
  ) as active_variant_count,
  exists (
    select 1
    from public.product_variants pv
    where pv.product_id = p.id
      and pv.is_active = true
      and exists (
        select 1
        from public.get_variant_availability(pv.id) a
        where a.is_in_stock
      )
  ) as has_stock
from public.products p
join public.categories c on c.id = p.category_id
left join public.brands b on b.id = p.brand_id
where p.status = 'active'
  and c.is_active = true
  and (b.id is null or b.is_active = true);

comment on view public.product_catalog is
  'Public catalog projection. security_invoker=true. No cost_price. '
  'has_stock uses get_variant_availability so anon needs no inventory SELECT. '
  'Flutter should query this view for listing screens.';

-- ---------------------------------------------------------------------------
-- Revoke implicit / residual table & view privileges from public roles
-- ---------------------------------------------------------------------------
revoke all on table public.profiles from public, anon, authenticated;
revoke all on table public.addresses from public, anon, authenticated;
revoke all on table public.categories from public, anon, authenticated;
revoke all on table public.brands from public, anon, authenticated;
revoke all on table public.products from public, anon, authenticated;
revoke all on table public.product_variants from public, anon, authenticated;
revoke all on table public.product_images from public, anon, authenticated;
revoke all on table public.inventory from public, anon, authenticated;
revoke all on table public.favorites from public, anon, authenticated;
revoke all on table public.carts from public, anon, authenticated;
revoke all on table public.cart_items from public, anon, authenticated;
revoke all on table public.orders from public, anon, authenticated;
revoke all on table public.order_items from public, anon, authenticated;
revoke all on table public.order_status_history from public, anon, authenticated;
revoke all on table public.product_catalog from public, anon, authenticated;
revoke all on table public.inventory_availability from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- anon: catalog-safe reads only (no customer/order/inventory writes or reads)
-- ---------------------------------------------------------------------------
grant select on table public.categories to anon;
grant select on table public.brands to anon;
grant select on table public.products to anon;
grant select on table public.product_images to anon;
grant select on table public.product_catalog to anon;

-- TASK-002: column-level SELECT only; never table-wide SELECT; no cost_price.
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
) on table public.product_variants to anon;

-- ---------------------------------------------------------------------------
-- authenticated: catalog reads + own customer surfaces + staff DML grants
-- (staff/admin authorization remains RLS via profiles.role)
-- ---------------------------------------------------------------------------
grant select, update on table public.profiles to authenticated;

grant select, insert, update, delete on table public.addresses to authenticated;

grant select on table public.categories to authenticated;
grant select on table public.brands to authenticated;
grant select on table public.products to authenticated;
grant select on table public.product_images to authenticated;
grant select on table public.product_catalog to authenticated;

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
) on table public.product_variants to authenticated;

-- Staff/admin catalog writes (RLS: is_staff_or_admin). No DELETE gaps vs policies:
-- categories/brands/products/variants/images use FOR ALL → need INSERT/UPDATE/DELETE.
grant insert, update, delete on table public.categories to authenticated;
grant insert, update, delete on table public.brands to authenticated;
grant insert, update, delete on table public.products to authenticated;
grant insert, update, delete on table public.product_variants to authenticated;
grant insert, update, delete on table public.product_images to authenticated;

-- Inventory: staff SELECT + write (RLS). No anon grant.
grant select, insert, update, delete on table public.inventory to authenticated;

-- Favorites: own-row SELECT/INSERT/DELETE (no UPDATE policy).
grant select, insert, delete on table public.favorites to authenticated;

grant select, insert, update, delete on table public.carts to authenticated;
grant select, insert, update, delete on table public.cart_items to authenticated;

-- Orders: customers SELECT own; staff INSERT/UPDATE. No DELETE policy.
grant select, insert, update on table public.orders to authenticated;
grant select, insert on table public.order_items to authenticated;
grant select, insert on table public.order_status_history to authenticated;

-- ---------------------------------------------------------------------------
-- Explicit operational access for the service_role database role
-- (never-role credentials must never ship to Flutter).
-- ---------------------------------------------------------------------------
grant all on table public.profiles to service_role;
grant all on table public.addresses to service_role;
grant all on table public.categories to service_role;
grant all on table public.brands to service_role;
grant all on table public.products to service_role;
grant all on table public.product_variants to service_role;
grant all on table public.product_images to service_role;
grant all on table public.inventory to service_role;
grant all on table public.favorites to service_role;
grant all on table public.carts to service_role;
grant all on table public.cart_items to service_role;
grant all on table public.orders to service_role;
grant all on table public.order_items to service_role;
grant all on table public.order_status_history to service_role;
grant all on table public.product_catalog to service_role;
grant all on table public.inventory_availability to service_role;

-- ---------------------------------------------------------------------------
-- Function contracts (restate; do not broaden)
-- ---------------------------------------------------------------------------

-- Policy helpers (intentional Data API surface for RLS expressions).
revoke all on function public.is_staff_or_admin() from public;
grant execute on function public.is_staff_or_admin()
  to authenticated, anon, service_role;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin()
  to authenticated, anon, service_role;

-- Trigger / utility helpers.
revoke all on function public.set_updated_at() from public;
revoke all on function public.set_updated_at() from anon;
grant execute on function public.set_updated_at()
  to authenticated, service_role;

-- Auth signup trigger helper: revoke PUBLIC default; no client EXECUTE grant.
revoke all on function public.handle_new_user_profile() from public;
revoke all on function public.handle_new_user_profile() from anon;
revoke all on function public.handle_new_user_profile() from authenticated;

revoke all on function public.generate_order_number() from public;
revoke all on function public.generate_order_number() from anon;
grant execute on function public.generate_order_number()
  to authenticated, service_role;

revoke all on function public.cart_items_enforce_active_cart() from public;
revoke all on function public.cart_items_enforce_active_cart() from anon;
grant execute on function public.cart_items_enforce_active_cart()
  to authenticated, service_role;

-- Public catalog RPCs.
revoke all on function public.get_variant_availability(uuid) from public;
grant execute on function public.get_variant_availability(uuid)
  to anon, authenticated, service_role;

revoke all on function public.search_products(text, integer) from public;
grant execute on function public.search_products(text, integer)
  to anon, authenticated, service_role;

-- Trusted checkout: authenticated + service_role only.
revoke all on function public.checkout_cod(uuid, text) from public;
revoke all on function public.checkout_cod(uuid, text) from anon;
grant execute on function public.checkout_cod(uuid, text)
  to authenticated, service_role;

-- TASK-007 trigger-only helpers: service_role only.
revoke execute on function public.prevent_profile_privilege_escalation()
  from public;
revoke execute on function public.prevent_profile_privilege_escalation()
  from anon;
revoke execute on function public.prevent_profile_privilege_escalation()
  from authenticated;
grant execute on function public.prevent_profile_privilege_escalation()
  to service_role;

revoke execute on function public.assign_order_number() from public;
revoke execute on function public.assign_order_number() from anon;
revoke execute on function public.assign_order_number() from authenticated;
grant execute on function public.assign_order_number() to service_role;

revoke execute on function public.record_order_status_change() from public;
revoke execute on function public.record_order_status_change() from anon;
revoke execute on function public.record_order_status_change() from authenticated;
grant execute on function public.record_order_status_change() to service_role;

revoke execute on function public.validate_product_image_variant() from public;
revoke execute on function public.validate_product_image_variant() from anon;
revoke execute on function public.validate_product_image_variant()
  from authenticated;
grant execute on function public.validate_product_image_variant()
  to service_role;
