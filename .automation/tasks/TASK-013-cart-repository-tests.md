# TASK-013 — Add cart repository regression tests

Risk: medium

## Objective

- Add network-free regression coverage for the Supabase-backed cart repository while preserving the existing authenticated, owner-scoped Data API behavior.

## Scope

- Add narrow injectable query seams to `SupabaseCartRepository` only where needed for offline unit tests.
- Cover active-cart lookup/creation, cart loading, item enrichment, add/increment, quantity update, removal, and clear behavior.
- Cover cart/cart-item mapping and Postgrest failure mapping.
- Preserve the existing `CartRepository` interface and Riverpod provider wiring.

## Non-goals

- Do not change schema, deployed migrations, RLS, grants, checkout RPC, inventory reservation, Supabase configuration, or remote data.
- Do not change Cart UI/ViewModel behavior, pricing authority, or checkout totals.
- Do not add Addresses, Orders, or Notifications coverage in this task.
- Do not perform unrelated refactors or documentation cleanup.

## Allowed paths

- `lib/features/cart/data/repositories/`
- `test/features/cart/`
- `.automation/backlog.json`

## Acceptance criteria

- Unauthenticated operations that require an active cart return `UnauthorizedException` failures without invoking database seams.
- Existing active-cart lookup is scoped by authenticated `user_id` and `status = active`; missing carts are inserted with exactly owner ID, active status, and `VND` currency.
- `getCart` loads only the resolved cart ID, orders cart items by `created_at`, and maps cart fields and optional timestamps correctly.
- Cart-item enrichment uses explicit safe variant columns and never requests `cost_price` or `*`; product and primary product-image lookups stay limited to the referenced product IDs.
- Item mapping covers quantity, snapshot-price precedence, live-price fallback, product name/image, and composed variant labels.
- `addItem` increments an existing matching variant or inserts a new row with exactly cart ID, variant ID, and quantity, then reloads the cart.
- Positive quantity updates modify only the requested item; zero/negative quantities delete it; remove and clear use the correct item/cart filters, then return the existing repository contract.
- Every operation maps `PostgrestException` to `DatabaseException` with the database code preserved; auth failures remain `UnauthorizedException`.
- Existing production constructor, public repository interface, and Riverpod wiring remain compatible.
- Tests require no live Supabase instance or network access.

## Required quality gates

- `dart format --output=none --set-exit-if-changed lib/features/cart/data/repositories test/features/cart`
- `flutter analyze`
- `flutter test test/features/cart`
- `flutter test`
- `python3 scripts/automation.py policy-check`
