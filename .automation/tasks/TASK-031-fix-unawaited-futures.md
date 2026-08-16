# TASK-031 — Restore Flutter analyze after the async lint upgrade

Risk: low

## Objective

- Restore the green Flutter CI baseline by resolving the four
  `unawaited_return_in_try_block` warnings reported by Flutter 3.47.0.
- Preserve the existing result mapping and exception handling behavior.

## Known failures

`flutter analyze` currently reports warnings at:

1. `auth_local_data_source_impl.dart:40`
2. `supabase_cart_repository.dart:324`
3. `supabase_cart_repository.dart:400`
4. `supabase_cart_repository.dart:428`

Each warning is caused by returning a `Future` directly from inside a `try`
block, which allows asynchronous failures to bypass the surrounding catches.

## Scope

- Await the affected asynchronous calls inside their existing `try` blocks so
  asynchronous failures continue through the intended exception mapping.
- Add or adjust focused tests only if needed to prove asynchronous failures are
  caught and mapped as before.
- Do not refactor unrelated authentication or cart behavior.

## Allowed paths

- `lib/features/authentication/data/data_sources/auth_local_data_source_impl.dart`
- `lib/features/cart/data/repositories/supabase_cart_repository.dart`
- `test/features/authentication/`
- `test/features/cart/`

## Acceptance criteria

- All four `unawaited_return_in_try_block` warnings are eliminated without
  disabling or suppressing the lint.
- `readAccessToken` still returns the stored token and maps asynchronous storage
  failures to `CacheException` with the original cause and stack trace.
- Cart add, remove, and quantity-update operations still return the refreshed
  cart on success and map asynchronous refresh failures through their existing
  repository error contract.
- No UI, database schema, Supabase migration, dependency, CI configuration, or
  environment file changes.
- No tests are deleted, skipped, weakened, or made dependent on live services.

## Required quality gates

- `dart format --output=none --set-exit-if-changed lib/features/authentication/data/data_sources/auth_local_data_source_impl.dart lib/features/cart/data/repositories/supabase_cart_repository.dart test/features/authentication test/features/cart`
- `flutter analyze`
- `flutter test test/features/authentication test/features/cart`
- `flutter test`
- `git diff --check`
- `python3 scripts/automation.py policy-check`

## Forbidden actions

- Do not add ignore comments, change analyzer settings, weaken lint severity, or
  alter the CI workflow.
- Do not read or modify `.env*`, credentials, Supabase secrets, migrations, or
  generated dependency files.
- Do not change branches, remotes, or protected-branch settings.
