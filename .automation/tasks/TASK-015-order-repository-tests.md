# TASK-015 — Add order repository regression tests

Risk: medium

## Objective

- Add network-free regression coverage for the customer Supabase order repository and make its read queries explicitly authenticated and owner-scoped in addition to existing RLS.

## Scope

- Add narrow injectable query seams to `SupabaseOrderRepository` only where needed for offline tests.
- Cover paginated order history, order detail, order-item loading, row mapping, enum fallback, and Postgrest failure mapping.
- Require the authenticated user ID before either repository operation.
- Preserve the existing `OrderRepository` interface and Riverpod provider wiring.

## Non-goals

- Do not change schema, deployed migrations, RLS, grants, checkout RPC, order totals, payment state, order transitions, Supabase configuration, or remote data.
- Do not add customer order writes, cancellations, staff/admin order management, or status-history UI.
- Do not change Orders UI/ViewModel or route guards.
- Do not add Notifications coverage or perform unrelated refactors/documentation cleanup.

## Allowed paths

- `lib/features/orders/data/repositories/`
- `test/features/orders/`
- `.automation/backlog.json`

## Acceptance criteria

- Unauthenticated list and detail calls return `UnauthorizedException` failures without invoking database seams.
- List is explicitly filtered by authenticated `user_id`, orders by `placed_at` descending, and uses correct inclusive Supabase ranges for valid `page`/`pageSize` inputs.
- Invalid pagination (`page < 1` or `pageSize < 1`) returns a `ValidationException` failure without invoking a database seam.
- Detail lookup filters by both authenticated `user_id` and requested order ID before loading items.
- Order-item lookup is limited to the resolved order ID and ordered by `created_at` ascending.
- Order mapping covers identifiers, status/payment enums, all monetary snapshots, customer/address data, timestamps, and detail items.
- Unknown order/payment status strings retain the existing safe fallbacks (`pending` and `unpaid`).
- Order-item mapping covers required and optional identifiers/names/image plus price, quantity, line total, and product snapshot.
- Every operation maps `PostgrestException` to `DatabaseException` with the database code preserved; auth and pagination failures keep their typed exceptions.
- Repository remains read-only: no insert, update, delete, privileged key, or client-controlled order transition is introduced.
- Existing production constructor, public repository interface, and Riverpod wiring remain compatible; tests need no live Supabase/network access.

## Required quality gates

- `dart format --output=none --set-exit-if-changed lib/features/orders/data/repositories test/features/orders`
- `flutter analyze`
- `flutter test test/features/orders`
- `flutter test`
- `python3 scripts/automation.py policy-check`
