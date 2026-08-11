# TASK-018 — Refresh project, architecture, and Supabase documentation

Risk: low

## Objective

- Replace stale starter/future-milestone claims with an accurate, security-conscious description of the implemented Badminton Store application and its current limitations.

## Scope

- Refresh the root README, architecture guide, coding guidelines, Supabase README next steps, and readiness audit status using verified repository evidence.
- Align money guidance with the existing Dart entities and trusted server-side checkout boundary.
- Remove stale “later milestone” comments only from repositories/providers that are already wired to production Supabase implementations.
- Keep Notifications explicitly documented as unimplemented/placeholder.

## Non-goals

- Do not change runtime behavior, Dart signatures, imports, formatting rules, dependencies, schema, migrations, RLS, grants, Supabase configuration, or remote data.
- Do not claim Notifications or generic Supabase database/storage facades are implemented.
- Do not add speculative setup steps, real credentials, service-role examples, or production deployment claims.
- Do not rewrite ADR history or unrelated backend reference documents.

## Allowed paths

- `README.md`
- `docs/architecture.md`
- `docs/coding_guidelines.md`
- `docs/audits/application-readiness.md`
- `supabase/README.md`
- `lib/features/addresses/domain/repositories/address_repository.dart`
- `lib/features/cart/domain/repositories/cart_repository.dart`
- `lib/features/catalog/di/catalog_providers.dart`
- `lib/features/catalog/domain/repositories/brand_repository.dart`
- `lib/features/catalog/domain/repositories/category_repository.dart`
- `lib/features/favorites/domain/repositories/favorite_repository.dart`
- `lib/features/orders/domain/repositories/order_repository.dart`
- `lib/features/product/domain/repositories/product_repository.dart`
- `lib/features/search/domain/repositories/search_repository.dart`
- `.automation/backlog.json`

## Acceptance criteria

- README identifies the app as Badminton Store, lists the implemented commerce/auth/account flows, current Flutter/Supabase stack, environment setup via `.env.example`, run commands, and actual quality/database test commands without publishing secrets.
- README no longer presents the repository as a generic fake-API/Dio starter, publishes demo credentials, or instructs contributors to replace implemented adapters.
- Architecture docs describe current Supabase initialization, feature repository wiring, trusted `checkout_cod` boundary, Riverpod/MVVM/GoRouter flow, explicit configuration-error UX, and remaining Notifications/facade limitations accurately.
- Security guidance states that Flutter uses only publishable/legacy anon keys, never service-role/secret keys; authorization and trusted totals/order/inventory transitions remain server-side with RLS/RPC enforcement.
- Coding guidelines remove the false blanket `int` minor-unit rule. They document the current convention: PostgreSQL numeric is authoritative; Dart domain snapshots currently use `double` for whole VND values/display; clients must not calculate trusted checkout/accounting totals; formatting stays in UI helpers.
- Supabase README no longer lists wiring Flutter repositories as future work and keeps local reset/regression commands accurate without implying remote migration execution.
- Readiness audit marks documentation/money/stale-comment findings resolved by TASK-018, reflects TASK-011 through TASK-017 coverage at a high level, and leaves Notifications plus optional facade cleanup as remaining work.
- Stale “later milestone” comments are corrected only for repositories/providers that have concrete wired implementations; Notifications comments remain unchanged.
- Every technical claim is traceable to current code/migrations/tests; no generated token, env value, credential, secret, or raw connection detail is added.
- Only Markdown and comment text changes; `git diff` shows no executable Dart behavior change.

## Required quality gates

- `dart format --output=none --set-exit-if-changed lib/features/addresses/domain/repositories/address_repository.dart lib/features/cart/domain/repositories/cart_repository.dart lib/features/catalog/di/catalog_providers.dart lib/features/catalog/domain/repositories/brand_repository.dart lib/features/catalog/domain/repositories/category_repository.dart lib/features/favorites/domain/repositories/favorite_repository.dart lib/features/orders/domain/repositories/order_repository.dart lib/features/product/domain/repositories/product_repository.dart lib/features/search/domain/repositories/search_repository.dart`
- `flutter analyze`
- `flutter test`
- `git diff --check`
- `python3 scripts/automation.py policy-check`
