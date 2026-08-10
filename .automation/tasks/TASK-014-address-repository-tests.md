# TASK-014 — Add address repository regression tests

Risk: medium

## Objective

- Add network-free regression coverage for the Supabase-backed address repository and make every address operation explicitly authenticated and owner-scoped in addition to existing RLS.

## Scope

- Add narrow injectable query seams to `SupabaseAddressRepository` only where needed for offline tests.
- Cover list, get, create, update, delete, set-default, payload mapping, row mapping, and Postgrest failure mapping.
- Require the authenticated user ID before any address database operation.
- Preserve the existing `AddressRepository` interface and Riverpod provider wiring.

## Non-goals

- Do not change schema, deployed migrations, RLS, grants, checkout behavior, Supabase configuration, or remote data.
- Do not build or change the Addresses UI/form in this task.
- Do not redesign default-address atomicity or introduce an RPC in this task.
- Do not add Orders, Notifications, or route-guard coverage.
- Do not perform unrelated refactors or documentation cleanup.

## Allowed paths

- `lib/features/addresses/data/repositories/`
- `test/features/addresses/`
- `.automation/backlog.json`

## Acceptance criteria

- Unauthenticated list, get, create, update, delete, and set-default calls return `UnauthorizedException` failures without invoking a database seam.
- List is explicitly filtered by authenticated `user_id`, orders defaults first and newest `updated_at` next, and maps every required/optional address field.
- Get and delete are filtered by both authenticated `user_id` and requested address ID.
- Create ignores caller-provided address/user IDs and inserts exactly the authenticated owner plus editable address fields; a default create clears only the authenticated user's prior default rows first.
- Update filters by both authenticated owner and address ID; its payload cannot reassign ownership and includes only editable address fields.
- Setting a default clears only the authenticated user's existing default rows, optionally excluding the target ID, then updates only that owner's target address.
- Non-default create/update does not invoke the clear-default seam.
- Every operation maps `PostgrestException` to `DatabaseException` with the database code preserved; auth failures remain `UnauthorizedException`.
- Existing production constructor, public repository interface, and Riverpod wiring remain compatible.
- Tests require no live Supabase instance or network access.

## Required quality gates

- `dart format --output=none --set-exit-if-changed lib/features/addresses/data/repositories test/features/addresses`
- `flutter analyze`
- `flutter test test/features/addresses`
- `flutter test`
- `python3 scripts/automation.py policy-check`
