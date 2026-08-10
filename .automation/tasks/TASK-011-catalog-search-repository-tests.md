# TASK-011 — Add catalog and search repository regression tests

Risk: medium

## Objective

- Add focused unit coverage for the Supabase-backed catalog and search repositories, including their query contracts, row mapping, error mapping, and recent-search behavior.

## Scope

- Add narrow injectable query/RPC seams to the catalog and search repositories only where needed to test them without network access.
- Cover brand `getById` and ordered list behavior.
- Cover category `getById`, `getBySlug`, and ordered list behavior.
- Cover search RPC name/parameters, product mapping, and Postgrest failure mapping.
- Cover recent-query read, deduplication, trimming, eight-item cap, blank-query handling, clearing, and malformed/non-list stored JSON without crashing.
- Preserve the existing public repository interfaces and Riverpod wiring.

## Non-goals

- Do not change schema, migrations, RLS, grants, Supabase configuration, or remote data.
- Do not change catalog/search UI, navigation, product mapping semantics, or production query behavior.
- Do not add coverage for favorites, cart, addresses, orders, or notifications in this task.
- Do not perform unrelated refactors or documentation cleanup.

## Allowed paths

- `lib/features/catalog/data/repositories/`
- `lib/features/search/data/repositories/`
- `test/features/catalog/`
- `test/features/search/`
- `.automation/backlog.json`

## Acceptance criteria

- Tests assert that brand/category lookups target the correct table and filter column, and lists remain ordered by `sort_order`.
- Tests assert successful rows map all required and optional entity fields correctly.
- Catalog repository `PostgrestException` failures become `DatabaseException` failures with the database code preserved.
- Search tests assert `search_products` is called with exactly `p_query` and `p_limit`; client-provided totals, roles, or unrelated parameters are never introduced.
- Search result rows map through the existing catalog product mapper, and Postgrest errors become `DatabaseException` failures.
- Recent queries are trimmed, case-insensitively deduplicated with the newest first, capped at eight, skip blank input, and can be cleared.
- Missing, empty, malformed, or non-list recent-search storage returns a safe empty list rather than throwing.
- Existing repository interfaces, providers, and runtime behavior remain compatible.
- No live Supabase or network access is required by the new tests.

## Required quality gates

- `dart format --output=none --set-exit-if-changed lib/features/catalog/data/repositories lib/features/search/data/repositories test/features/catalog test/features/search`
- `flutter analyze`
- `flutter test test/features/catalog test/features/search`
- `flutter test`
- `python3 scripts/automation.py policy-check`
