# TASK-005 — Wire Flutter checkout to trusted COD RPC

Risk: high

## Objective

Replace the locked checkout placeholder with a complete authenticated MVP COD
checkout screen that selects an owned address, accepts an optional note, calls
`public.checkout_cod`, and navigates to an order-success/detail state. The
database remains the authority for identity, prices, totals, inventory, payment
state, and order creation.

## Scope

- Preserve feature-first MVVM, Riverpod DI, GoRouter, `Result`, repository, and
  exception-mapping patterns already used by the app.
- Add a checkout domain/repository contract and a Supabase implementation that
  calls only `checkout_cod(p_shipping_address_id, p_customer_note)` and parses
  the returned order UUID.
- Build a checkout ViewModel/state with explicit loading, ready, submitting,
  success, and failure behavior; prevent double submission.
- Load the current active cart and owned addresses through existing repositories.
- Select the default address initially, otherwise the first address. Let the
  customer choose another owned address.
- Show a clear empty-address state with a navigation/action path to manage or
  create addresses; do not invent a hard-coded checkout address.
- Display cart items and client-computed subtotal only as an estimate. Label
  COD, zero shipping, and the fact that the backend confirms authoritative
  totals/stock during checkout.
- Accept an optional customer note and pass only address ID + normalized note to
  the RPC. Never send user ID, cart ID, price, total, currency, inventory,
  payment status, order status, or role.
- On success, invalidate cart/order-related providers and navigate safely to an
  existing order detail/list route when available; otherwise show a durable
  success state containing the returned order ID and a safe navigation action.
- Map authentication, invalid address/cart, insufficient stock, inactive
  catalog/profile, and generic backend failures to actionable Vietnamese UI
  messages without exposing SQL internals.
- Add focused repository, ViewModel, and widget tests for success, failures,
  address selection, empty cart/address, loading, and duplicate-submit guards.
- Remove or replace `checkoutReadyProvider`; checkout must no longer be a false
  placeholder flag.

## Security requirements

- Flutter may use only the existing Supabase publishable/anon client and the
  authenticated user session. Never use or mention a service-role key in code.
- Call the trusted RPC; never write directly to `orders`, `order_items`,
  `inventory`, or order status tables.
- Treat every displayed cart price/total as informational. Do not use client
  totals as checkout inputs or claim they are authoritative.
- Do not decode JWT metadata or use client-side roles for authorization.
- Do not change database schema, migrations, RLS, function grants, or remote
  Supabase state in this task.
- Do not leak raw PostgREST/SQL errors, tokens, claims, or customer data into
  logs or user-visible messages.

## Acceptance criteria

- Authenticated customer with a non-empty cart and owned address can submit COD
  checkout exactly once and receives the returned order ID.
- The RPC payload contains exactly `p_shipping_address_id` and
  `p_customer_note`; tests assert no price/total/user/cart/status fields exist.
- Default/first address selection and manual address switching work.
- Missing address, empty cart, loading, retryable failure, insufficient stock,
  and successful submission are represented clearly in the UI.
- Repeated taps while submitting cannot create multiple RPC calls.
- After success the cart is refreshed/invalidated and the user has a reliable
  route away from checkout toward order history/detail or shopping.
- Checkout repository maps Supabase failures into project `Result` failures and
  never exposes raw backend messages directly in the UI.
- Repository, ViewModel, and widget tests cover the changed behavior.
- Cursor runs `dart format --output=none --set-exit-if-changed .`,
  `flutter analyze`, `flutter test`, and the automation policy check; all pass.
- Cursor commits, pushes the task branch, and opens a PR targeting `develop`
  with the real gate results. Cursor does not merge the PR.

## Allowed paths

- `lib/features/checkout`
- `lib/features/cart/presentation/views/cart_page.dart`
- `lib/features/addresses`
- `lib/features/orders`
- `lib/app/router`
- `test/features/checkout`
- `test/features/cart`
- `test/features/addresses`
- `test/features/orders`
- `docs/backend/flutter_integration_notes.md`
- `docs/audits/application-readiness.md`

## Forbidden actions

- Do not edit `supabase/`, environment files, secrets, automation governance,
  CI, or unrelated features.
- Do not add online payments, coupons, shipping integrations, guest checkout,
  order cancellation, inventory release, or fulfillment behavior.
- Do not trust or submit client-derived totals.
- Do not push to or merge into `develop`, force-push, change branches/remotes,
  or close/approve the PR.
- Do not contact or mutate remote Supabase.
