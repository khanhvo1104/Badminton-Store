# TASK-012 — Add favorites repository regression tests

Risk: medium

## Objective

- Add network-free unit coverage for the Supabase-backed favorites repository, protecting its authentication boundary, query contracts, mapping, and error handling.

## Scope

- Add narrow injectable query seams to `SupabaseFavoriteRepository` only where needed for offline tests.
- Cover add, remove, contains, and list operations.
- Cover favorite entity mapping and Postgrest failure mapping.
- Preserve the existing `FavoriteRepository` interface and Riverpod provider wiring.

## Non-goals

- Do not change schema, migrations, RLS, grants, authentication behavior, Supabase configuration, or remote data.
- Do not change Favorites UI/ViewModel behavior or add product-detail hydration.
- Do not add Cart, Addresses, Orders, or Notifications coverage in this task.
- Do not perform unrelated refactors or documentation cleanup.

## Allowed paths

- `lib/features/favorites/data/repositories/`
- `test/features/favorites/`
- `.automation/backlog.json`

## Acceptance criteria

- Unauthenticated add, remove, contains, and list calls return `UnauthorizedException` failures without invoking a database seam.
- Add targets `favorites` and writes exactly the authenticated `user_id` plus requested `product_id`; it maps the returned row correctly.
- Remove is restricted by both authenticated `user_id` and requested `product_id`.
- Contains selects only `product_id`, filters by both authenticated user and product, and returns true/false from row presence.
- List filters by authenticated `user_id`, orders by `created_at` descending, and maps required/optional fields including the composite entity ID.
- Every operation maps `PostgrestException` to `DatabaseException` while preserving the database error code.
- Existing production constructor, public repository interface, and Riverpod wiring remain compatible.
- Tests require no live Supabase instance or network access.

## Required quality gates

- `dart format --output=none --set-exit-if-changed lib/features/favorites/data/repositories test/features/favorites`
- `flutter analyze`
- `flutter test test/features/favorites`
- `flutter test`
- `python3 scripts/automation.py policy-check`
