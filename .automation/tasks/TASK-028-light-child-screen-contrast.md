# TASK-028 — Restore readable light UI on child screens

Risk: medium

## Objective

- Make every authenticated child screen visually consistent with the existing light storefront and ensure all foreground content remains readable.

## Scope

- Audit the shared Flutter theme and authenticated child pages for implicit dark surfaces, transparent scaffolds, and hard-coded foreground colors that produce dark-on-black content.
- Prefer a shared light-theme/background correction over repeated page-specific color overrides.
- Update only presentation/theme code and focused widget or theme tests needed to cover the regression.

## Non-goals

- Do not redesign the Home storefront, alter navigation, repositories, domain/data layers, Supabase, schemas, migrations, dependencies, product behavior, copy, or business logic.
- Do not introduce a dark theme or automatic system-theme switching in this task.
- Do not replace the established mint, off-white, glass-card, spacing, typography, or component language shown on Home.

## Allowed paths

- `lib/app/theme/`
- `lib/core/ui/`
- `lib/shared/widgets/`
- `lib/features/addresses/presentation/`
- `lib/features/cart/presentation/`
- `lib/features/catalog/presentation/`
- `lib/features/checkout/presentation/`
- `lib/features/favorites/presentation/`
- `lib/features/home/presentation/`
- `lib/features/notifications/presentation/`
- `lib/features/orders/presentation/`
- `lib/features/product/presentation/`
- `lib/features/profile/presentation/`
- `lib/features/search/presentation/`
- `lib/features/settings/presentation/`
- `test/app/theme/`
- `test/core/ui/`
- `test/shared/widgets/`
- `test/features/`
- `.automation/backlog.json`

## Acceptance criteria

- Product detail and every authenticated child screen use a light/off-white or mint-tinted background consistent with Home; no screen falls back to a black scaffold or route surface.
- App bars, titles, body copy, section labels, prices, stock labels, icons, controls, loading/empty/error states, dialogs, sheets, and form fields meet clear light-theme contrast and do not inherit dark-on-black combinations.
- Existing semantic roles, touch targets, navigation, state handling, and business behavior remain unchanged.
- Shared theme tokens are the primary source of surface and foreground colors; any explicit page-level color is justified by a component-specific need.
- Product cards, variant controls, bottom navigation, and glass treatments preserve the existing storefront visual language.
- The fix remains correct when the host device requests dark appearance because this app currently presents a deliberate light storefront.
- Focused tests reproduce the original regression and verify representative child screens, including Product detail plus at least Catalog, Cart, Favorites, Profile, Orders, Addresses, Search, and Notifications, render with a non-black surface and readable primary text.
- Tests use provider/router overrides and no live Supabase or network access.

## Required quality gates

- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`
- `git diff --check`
- `python3 scripts/automation.py policy-check`
