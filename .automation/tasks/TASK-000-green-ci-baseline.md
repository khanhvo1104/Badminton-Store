# TASK-000 — Restore a green Flutter CI baseline

Risk: medium

## Objective

Make the existing repository pass formatting, static analysis, and tests without changing intended product behavior.

## Known failures

1. Fifteen Dart files do not match the formatter bundled with Flutter 3.44.8.
2. `profile_view_model_test.dart` and `login_view_model_test.dart` can resolve the real Supabase provider instead of a test double.
3. Login widget expectations for demo credentials no longer match the intended UI/configuration boundary.
4. The authentication flow widget expectation for the login screen is stale.
5. The settings/logout test triggers Flutter's `ListTile`/`DecoratedBox` Material ancestor assertion.

## Acceptance criteria

- The repository matches the Dart formatter shipped with Flutter 3.44.8.
- Unit and widget tests do not initialize or contact a real Supabase project.
- Test dependency overrides are deterministic and shared through existing test helpers where appropriate.
- UI expectations reflect the intended current behavior, not incidental implementation details.
- The `ListTile` Material ancestor assertion is fixed without visually redesigning Settings.
- No tests are deleted, skipped, weakened, or made order-dependent.
- No environment file, dependency, Supabase migration, database schema, or Git configuration changes.
- `dart format --output=none --set-exit-if-changed .` passes.
- `flutter analyze` passes.
- `flutter test` passes.
- `python3 scripts/automation.py policy-check` passes before staging.

## Allowed paths

- `lib/features/addresses/data/repositories/supabase_address_repository.dart`
- `lib/features/addresses/presentation/views/addresses_page.dart`
- `lib/features/authentication/`
- `lib/features/cart/data/repositories/supabase_cart_repository.dart`
- `lib/features/cart/presentation/views/cart_page.dart`
- `lib/features/catalog/presentation/views/catalog_page.dart`
- `lib/features/favorites/presentation/views/favorites_page.dart`
- `lib/features/home/data/data_sources/supabase_home_remote_data_source.dart`
- `lib/features/orders/data/repositories/supabase_order_repository.dart`
- `lib/features/orders/presentation/views/orders_page.dart`
- `lib/features/product/data/repositories/supabase_product_repository.dart`
- `lib/features/product/presentation/views/product_detail_page.dart`
- `lib/features/profile/`
- `lib/features/search/data/repositories/supabase_search_repository.dart`
- `lib/features/search/presentation/views/search_page.dart`
- `lib/features/settings/presentation/views/settings_page.dart`
- `test/`

## Forbidden actions

- Do not edit `.env*`, `pubspec.yaml`, `pubspec.lock`, or `supabase/`.
- Do not connect to a real Supabase project or require Supabase credentials in tests.
- Do not modify Git state.
- Do not add sleeps, retries, broad exception swallowing, test skips, or reduced assertions to hide failures.

