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

`storage_path`; optional `variant_id` validated against `product_id`; one primary general image per product.

## inventory

PK `variant_id`. Reserved ≤ on_hand unless `allow_backorder`. Public uses `get_variant_availability`.

## favorites

Composite PK (user_id, product_id).

## carts / cart_items

XOR owner (`user_id` XOR `guest_token`); one active cart per user; unique (cart_id, variant_id); quantity > 0.

## orders / order_items / order_status_history

Order number `BDM-YYYYMMDD-XXXXXX`; grand_total math check; shipping_address jsonb snapshot; line_total = unit_price * quantity; status history via trigger.

## Views / RPCs

- `product_catalog` (security_invoker)
- `inventory_availability` (staff-oriented; public uses RPC)
- `get_variant_availability(uuid)`
- `search_products(text, int)`
- `generate_order_number()`
- `is_staff_or_admin()` / `is_admin()`
