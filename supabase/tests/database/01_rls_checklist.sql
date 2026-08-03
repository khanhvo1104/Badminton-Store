-- RLS expectation checklist (manual / pgTAP later).
-- Documented scenarios — execute with role switching when local Supabase runs.

/*
Anonymous:
  - SELECT products where status=active → allowed
  - SELECT products where status=draft → denied / empty
  - INSERT products → denied
  - SELECT profiles → denied
  - SELECT addresses/carts/orders → denied
  - SELECT product_variants.cost_price via catalog view → not present

Customer A:
  - SELECT/UPDATE own profile (role unchanged)
  - CRUD own addresses
  - Cannot SELECT customer B addresses
  - CRUD own favorites/cart
  - SELECT own orders only
  - Cannot UPDATE orders.status / totals

Admin:
  - Manage catalog + inventory
  - SELECT all orders
  - UPDATE permitted order workflow fields

Triggers:
  - INSERT auth.users → one profiles row
  - UPDATE any mutable row → updated_at changes
  - UPDATE orders.status → order_status_history row
  - INSERT orders without order_number → generated BDM-* value
*/

select 'See comments in this file for RLS test plan' as note;
