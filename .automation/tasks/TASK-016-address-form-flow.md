# TASK-016 — Replace the demo address action with a validated form flow

Risk: medium

## Objective

- Replace the hard-coded sample-address FAB with a production-usable create/edit address form and safe mutation feedback, while preserving the existing Supabase repository and owner/RLS boundaries.

## Scope

- Add a feature-scoped MVVM/Riverpod presentation flow for creating and editing addresses through `AddressRepository`.
- Add free-text Vietnam-oriented recipient, phone, province, district, ward, street, optional note, and default-address fields; administrative codes remain optional/unset until a dedicated location-data task.
- Integrate create/edit actions into `AddressesPage` and refresh the list only after successful mutations.
- Add confirmation and user-visible success/failure behavior for destructive/default actions.
- Add focused ViewModel and widget tests with a fake repository; no live Supabase/network access.

## Non-goals

- Do not change schema, migrations, RLS, grants, repository query contracts, checkout RPC, Supabase configuration, or remote data.
- Do not add a provinces/districts/wards API, autocomplete, maps, geocoding, or new package dependency.
- Do not change checkout address selection or navigation architecture.
- Do not redesign default-address atomicity or add an RPC.
- Do not perform unrelated visual redesigns or refactors.

## Allowed paths

- `lib/features/addresses/presentation/`
- `lib/features/addresses/di/`
- `test/features/addresses/`
- `.automation/backlog.json`

## Acceptance criteria

- The FAB label is `Thêm địa chỉ` and opens an empty address form; no hard-coded sample address is created.
- Existing address actions include `Chỉnh sửa`; edit opens the same form prefilled and preserves the target address ID.
- Recipient name, phone, province, district, ward, and street are required after trimming; optional note is trimmed and blank becomes null.
- Phone validation accepts a reasonable Vietnamese local format and rejects clearly invalid input with inline Vietnamese guidance; validation does not call the repository.
- The default-address switch maps to `isDefault`; create/update entities never supply trusted ownership (the repository remains responsible for authenticated `user_id`).
- Submit has visible progress, blocks duplicate submission, calls exactly create or update as appropriate, closes on success, invalidates/reloads the address list, and shows a sanitized Vietnamese error without closing on failure.
- Delete requires confirmation; cancel performs no mutation. Delete and set-default show progress/disable duplicate actions, surface sanitized failures, and refresh only after success.
- Empty/loading/error/list states remain pull-to-refresh compatible, and default addresses have a visible `Mặc định` indicator.
- Presentation logic follows existing MVVM/Riverpod boundaries and does not access `SupabaseClient` directly.
- Widget/ViewModel tests cover create validation/success/failure, edit prefill/update, duplicate-submit prevention, delete confirmation, default action, and list refresh behavior.

## Required quality gates

- `dart format --output=none --set-exit-if-changed lib/features/addresses/presentation lib/features/addresses/di test/features/addresses`
- `flutter analyze`
- `flutter test test/features/addresses`
- `flutter test`
- `python3 scripts/automation.py policy-check`
