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
| get_staff_variant_costs | —† | —† | R (cost-only RPC) |
| product_catalog view | R | R | R |
| profiles | — | R/U (no role) | R/U |
| addresses | — | CRUD | R |
| favorites | — | CRUD | — |
| carts / cart_items | — | CRUD own active | R |
| orders / order_items / history | — | R own | R + U orders |

\* Public variant reads never expose `cost_price` through `product_catalog`.
  Direct `product_variants.cost_price` SELECT remains denied to `anon` and
  `authenticated` (column grants). Staff/admin cost reads use the RPC below.

† `get_staff_variant_costs(uuid)`: EXECUTE is granted only to PostgreSQL role
  `authenticated` (not `anon` / `service_role` / `PUBLIC`). Authorization still
  requires an active trusted `profiles.role` of `staff` or `admin`, so anonymous
  callers, customers, inactive staff, missing profiles, unsupported roles, and
  forged JWT metadata are denied the same generic authorization failure.
  Active staff/admin receive only `variant_id` + nullable `cost_price` for the
  requested product. Existing variant RLS and safe-column grants are unchanged.

## Key rules

- Customers cannot change `profiles.role` / `is_active` (trigger + policy).
- Customers cannot insert/update orders or order_items (checkout RPC later).
- Guest carts are schema-supported but **not** exposed via anon `guest_token` RLS.
- Staff checks use `public.is_staff_or_admin()` (SECURITY DEFINER on `profiles.role`).
- Cost-price reads for CMS use `public.get_staff_variant_costs` (trusted profile
  check inside the RPC); do not grant `SELECT(cost_price)` to `authenticated`.
