# Database schema reference

Conventions: UUID PKs, `timestamptz`, `numeric(14,2)` money, text status + checks, Storage paths.

## profiles

Auth-linked customer/staff profile.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | = auth.users.id, ON DELETE CASCADE |
| full_name | text | nullable |
| phone_number | text | nullable |
| avatar_path | text | Storage path |
| date_of_birth | date | nullable |
| gender | text | check male/female/other/unspecified |
| role | text | customer\|staff\|admin, default customer |
| is_active | boolean | default true |
| created_at / updated_at | timestamptz | trigger |

RLS: own read/update; role locked by trigger; staff can manage.

## addresses

VN shipping addresses. Partial unique index: one `is_default` per user.

## categories / brands

Catalog taxonomy. Unique `slug`. Self-FK parent on categories with no self-parent.

## products

| Important | |
|-----------|--|
| status | draft\|active\|inactive\|archived |
| specifications | jsonb |
| search_vector | generated tsvector |
| published_at | required when active |

No stock/price on this table.

## product_variants

SKU unique; price/compare_at/cost numeric; badminton columns (racket_weight_class, grip_size, shoe_size, clothing_size); one default per product.

## product_images

`storage_path`; optional `variant_id` validated against `product_id`; one primary general image per product and one primary per variant. CMS primary switches use `set_cms_product_image_primary`; bounded reorders use `reorder_cms_product_images`. Inserts and variant reassignment use `insert_cms_product_image` / `update_cms_product_image` so primary maintenance is one transaction.

## inventory

PK `variant_id`. Reserved ≤ on_hand unless `allow_backorder`. Public uses `get_variant_availability`. CMS adjustments use `adjust_cms_inventory` and write immutable `inventory_history`.

## favorites

Composite PK (user_id, product_id).

## carts / cart_items

XOR owner (`user_id` XOR `guest_token`); one active cart per user; unique (cart_id, variant_id); quantity > 0.

## orders / order_items / order_status_history

Order number `BDM-YYYYMMDD-XXXXXX`; grand_total math check; shipping_address jsonb snapshot; line_total = unit_price * quantity; status history via trigger. Authenticated roles have SELECT/INSERT on `orders` but not UPDATE; status transitions use `transition_cms_order_status`.

## Views / RPCs

- `product_catalog` (security_invoker)
- `inventory_availability` (staff-oriented; public uses RPC)
- `get_variant_availability(uuid)`
- `get_staff_variant_costs(p_product_id uuid)` → `(variant_id uuid, cost_price numeric(14,2))`
  - STABLE SECURITY DEFINER, `SET search_path = ''`
  - Returns every variant for that product only, ordered by `sort_order, id`
  - Authorizes active trusted `profiles.role` in (`staff`, `admin`) via `auth.uid()`
  - EXECUTE: `authenticated` only (revoked from `PUBLIC`, `anon`, `service_role`)
  - Does not change variant RLS or grant `SELECT(cost_price)` to public API roles
- `list_cms_inventory(text, text, text, int, int)` — STABLE SECURITY INVOKER, empty search_path, staff/admin only
- `adjust_cms_inventory(uuid, text, int, bool, text, text)` — VOLATILE SECURITY DEFINER, empty search_path, staff/admin only, history + inventory in one transaction, returns only `variant_id`
- `list_cms_orders(text, text, text, timestamptz, timestamptz, text, int, int)` — STABLE SECURITY INVOKER, empty search_path, staff/admin only
- `transition_cms_order_status(uuid, text, text)` — VOLATILE SECURITY DEFINER, empty search_path, staff/admin only, locks order + inventory, enforces transition graph and inventory effects, returns only `order_id`
- `get_cms_operational_dashboard(int)` — STABLE SECURITY INVOKER, empty search_path, staff/admin only, currency-aware gross metrics and daily series without cross-currency summation, bounded low-stock variants
- `set_cms_product_image_primary(uuid, uuid)` — VOLATILE SECURITY INVOKER, empty search_path, staff/admin only, serializes unique primary switches, returns only `image_id`
- `reorder_cms_product_images(uuid, uuid[])` — VOLATILE SECURITY INVOKER, empty search_path, staff/admin only, bounded complete id list, returns only `product_id`
- `insert_cms_product_image(uuid, text, text, uuid, boolean)` — VOLATILE SECURITY INVOKER, empty search_path, staff/admin only, insert + optional primary in one transaction, returns only `image_id`
- `update_cms_product_image(uuid, uuid, text, uuid, integer)` — VOLATILE SECURITY INVOKER, empty search_path, staff/admin only, variant move + primary maintenance in one transaction, returns only `image_id`
- `search_products(text, int)`
- `generate_order_number()`
- `is_staff_or_admin()` / `is_admin()`
