# TASK-029 — Prevent ProductCard overflow for long product names

Risk: low

## Objective

- Make product cards remain stable and readable when product names are long, localized, or rendered on narrow mobile screens.

## Scope

- Reproduce the overflow in the reusable `ProductCard` and its Catalog, Search, and Favorites grid contexts.
- Fix layout constraints at the shared component/grid level with a responsive solution.
- Add focused network-free widget regression tests using realistically long Vietnamese product names, narrow viewport widths, text scaling, discount pricing, and stock content.

## Non-goals

- Do not change product data, repositories, navigation, Supabase, copy, theme, dependencies, image loading, prices, inventory behavior, or unrelated storefront components.
- Do not hide the price or stock state to make the card fit.
- Do not reduce text to an inaccessible fixed font size.

## Allowed paths

- `lib/shared/widgets/shop/`
- `lib/features/catalog/presentation/`
- `lib/features/search/presentation/`
- `lib/features/favorites/presentation/`
- `test/shared/widgets/shop/`
- `test/features/catalog/`
- `test/features/search/`
- `test/features/favorites/`
- `.automation/backlog.json`

## Acceptance criteria

- Product titles never paint or flex outside the card at supported mobile widths; titles use a deliberate line limit and ellipsis while preserving a semantics label containing the full name.
- Cards with one-line and long two-line titles maintain consistent grid alignment and enough room for image, price, optional compare-at price, and optional stock indicator.
- The layout remains overflow-free at a narrow 320 logical-pixel viewport and text scale up to 1.3.
- Catalog, Search, and Favorites use the same responsive card sizing strategy rather than three drifting hard-coded grid configurations.
- Existing tap/favorite behavior, visual storefront language, prices, stock states, and accessibility targets remain unchanged.
- Widget tests fail on the previous layout and verify no Flutter overflow exceptions for long Vietnamese names with the densest optional content.
- Tests use provider/router overrides where necessary and no live Supabase/network access.

## Required quality gates

- `dart format --output=none --set-exit-if-changed lib/shared/widgets/shop lib/features/catalog/presentation lib/features/search/presentation lib/features/favorites/presentation test/shared/widgets/shop test/features/catalog test/features/search test/features/favorites`
- `flutter analyze`
- `flutter test`
- `git diff --check`
- `python3 scripts/automation.py policy-check`
