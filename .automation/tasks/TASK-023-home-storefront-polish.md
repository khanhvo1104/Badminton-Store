# TASK-023 — Turn Home into a navigable storefront

Risk: medium

## Objective

- Replace the generic dashboard presentation on Home with a tested badminton-storefront experience around the existing featured `product_catalog` items and application routes.

## Scope

- Update Home presentation copy, layout, actions, and featured-item cards while preserving the existing Home repository/data-source contract.
- Make each featured item navigate to its product detail route.
- Add clear Catalog and Search entry points, sanitized loading/error/empty behavior, refresh behavior, accessibility, and network-free ViewModel/widget tests.

## Non-goals

- Do not change Home repository/data-source/model/domain contracts, Product repositories, `product_catalog`, schema, migrations, RLS, grants, seed data, Supabase configuration, or remote data.
- Do not add prices/images/favorites/cart actions to featured cards because the current Home item contract does not contain those fields.
- Do not add promotions, banners, analytics, recommendations, personalization, Realtime, pagination, dependencies, or routes.
- Do not redesign Catalog, Search, Product detail, shell navigation, theme, or unrelated shared widgets.

## Allowed paths

- `lib/features/home/presentation/`
- `test/features/home/`
- `.automation/backlog.json`

## Acceptance criteria

- Loaded Home greets the signed-in user and uses store-oriented copy rather than dashboard/overview language.
- A clearly labelled featured-products section renders repository items in existing order with stable widget keys and responsive one/two-column behavior.
- Each featured item is keyboard/touch accessible, exposes a concise product semantics label, and navigates with `context.push(AppRoutes.productDetail(item.id))`.
- Home provides stable, accessible Catalog and Search actions that navigate to `AppRoutes.catalog` and `AppRoutes.search` without altering shell routing.
- Pull-to-refresh remains available for loaded and empty states and invokes the existing Home ViewModel refresh exactly once per gesture.
- Full-screen loading, empty, and failure states remain reachable with stable test keys; empty offers Catalog and failure offers Retry.
- Repository failures map to sanitized user-facing copy for authentication, network, and generic failures; raw SQL/backend/exception text is never rendered.
- Refresh failure preserves loaded featured items and exposes consumable sanitized feedback without replaying it on rebuild.
- Duplicate refresh requests are ignored while one is in flight, and late async completions do not update a disposed ViewModel.
- Existing current-user greeting selection and repository/data-source contracts remain compatible; no direct `SupabaseClient` access is added to presentation code.
- Tests cover load success/order, empty, sanitized initial failure/retry, successful refresh, refresh failure preserving content, duplicate refresh guard, disposal safety, responsive layout, product/catalog/search navigation, and accessibility labels.
- Tests use repository/provider/router overrides and no live Supabase/network access.

## Required quality gates

- `dart format --output=none --set-exit-if-changed lib/features/home/presentation test/features/home`
- `flutter analyze`
- `flutter test test/features/home`
- `flutter test`
- `git diff --check`
- `python3 scripts/automation.py policy-check`
