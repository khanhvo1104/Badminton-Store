# RLS permission matrix

| Resource | anon | customer (own) | staff/admin |
|----------|------|----------------|-------------|
| categories (active) | R | R | CRUD |
| brands (active) | R | R | CRUD |
| products (active) | R | R | CRUD all statuses |
| product_variants (active+parent active) | R* | R* | CRUD |
| product_images (via active product) | R | R | CRUD |
| inventory (raw) | — | — | CRUD |
| get_variant_availability | R | R | R |
| product_catalog view | R | R | R |
| profiles | — | R/U (no role) | R/U |
| addresses | — | CRUD | R |
| favorites | — | CRUD | — |
| carts / cart_items | — | CRUD own active | R |
| orders / order_items / history | — | R own | R + U orders |

\* Public variant reads never expose `cost_price` through `product_catalog`.

## Key rules

- Customers cannot change `profiles.role` / `is_active` (trigger + policy).
- Customers cannot insert/update orders or order_items (checkout RPC later).
- Guest carts are schema-supported but **not** exposed via anon `guest_token` RLS.
- Staff checks use `public.is_staff_or_admin()` (SECURITY DEFINER on `profiles.role`).
