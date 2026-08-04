# TASK-004 — Build trusted COD checkout backend

Risk: high

## Objective

Implement an authenticated, server-trusted checkout transaction for the MVP COD
flow. The database must recompute prices and totals, reserve inventory, snapshot
the order, and convert the user's active cart atomically. Keep the Flutter
checkout UI locked; wiring the client is a later task.

## Scope

- Create a new Supabase migration with `supabase migration new`; never edit an
  existing migration.
- Add one narrowly scoped checkout RPC callable only by `authenticated` users.
- Derive the customer from `auth.uid()`; never accept a user ID, totals, prices,
  stock state, order status, payment status, or privileged role from the client.
- Accept only an owned shipping-address ID and an optional customer note.
- Support MVP `cod` only, with `payment_status = 'unpaid'`,
  `discount_total = 0`, and `shipping_fee = 0`.
- Lock the active cart and relevant inventory rows in a deterministic order.
- Re-read active product/variant prices and reject empty carts, invalid catalog
  rows, invalid quantities, cross-user addresses, inactive profiles, and
  insufficient stock unless that inventory row explicitly allows backorder.
- Reserve stock atomically, insert `orders` and immutable `order_items`
  snapshots, then mark the cart `converted` in the same transaction.
- Return only the new order ID. Do not return internal cost, inventory internals,
  or privileged fields.
- Add executable local database tests for authorization, validation, totals,
  snapshots, stock reservation, cart conversion, idempotent retry behavior, and
  rollback on failure.
- Update checkout security documentation and the readiness audit only for this
  backend milestone.

## Security requirements

- Prefer `SECURITY DEFINER` only because customer RLS intentionally blocks
  direct order/inventory writes. Use `set search_path = ''` and fully qualify
  every schema object and function.
- Revoke function execution from `PUBLIC` and `anon`; grant only to
  `authenticated` and `service_role` after validating `auth.uid()` inside the
  function.
- Do not use user-editable JWT metadata for authorization.
- Do not expose a generic privileged write function or broaden table RLS.
- Do not trust cart price snapshots; use current `product_variants.price`.
- Acquire locks deterministically and make every failure roll back order rows,
  reservations, status history, and cart conversion.
- Do not log or return secrets, internal `cost_price`, or full authentication
  tokens.

## Acceptance criteria

- An unauthenticated/anon caller cannot execute checkout.
- A user cannot checkout another user's cart or address.
- A valid active user with an owned address and non-empty active cart receives
  exactly one new pending COD order whose totals are server-computed.
- Order-item snapshots contain current product/variant names, SKU, current sale
  price, quantity, line total, and a safe product snapshot without `cost_price`.
- Inventory reservation and cart conversion happen atomically.
- Insufficient stock or any invalid line produces no order and no partial stock
  reservation.
- Retrying after cart conversion cannot create a duplicate order.
- Existing customer direct INSERT/UPDATE restrictions on orders and inventory
  remain unchanged.
- The RPC has an empty fixed search path and least-privilege EXECUTE grants.
- Executable SQL tests pass against the disposable local Supabase stack.
- Formatting, `flutter analyze`, `flutter test`, automation policy checks,
  migration checks, and relevant security checks pass.
- No remote Supabase migration is applied by Cursor or during implementation.

## Allowed paths

- `supabase/migrations`
- `supabase/tests/database`
- `docs/backend/checkout_security.md`
- `docs/audits/application-readiness.md`

## Forbidden actions

- Do not edit deployed migrations.
- Do not modify Flutter checkout UI/providers/repositories in this task.
- Do not add online payment, coupons, shipping-provider integrations, guest
  checkout, order cancellation, inventory release, or staff fulfillment flows.
- Do not accept client-computed prices or totals.
- Do not grant order/inventory table writes directly to customers.
- Do not expose the RPC to `anon` or implicit `PUBLIC` execute privileges.
- Do not access or mutate the remote Supabase project.
- Do not read environment or secret files.

