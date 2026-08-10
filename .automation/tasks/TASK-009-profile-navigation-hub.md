# TASK-009 — Add an account navigation hub to Profile

Risk: medium

## Objective

Make the already-registered account routes reachable from the authenticated
Profile tab. Add clear navigation entries for orders, addresses, and settings
(including the existing logout flow) without changing router architecture or
implementing unfinished notifications functionality.

## Scope

- Add an account/navigation section to the loaded state of `ProfilePage`.
- Link to `AppRoutes.orders`, `AppRoutes.addresses`, and `AppRoutes.settings`
  through GoRouter using the appropriate push behavior so returning preserves
  the Profile shell state.
- Use existing glass/design-system components where practical and keep the
  layout responsive, accessible, and usable while profile saving is in flight.
- Add focused widget tests that tap every entry and prove the expected route is
  reached. Preserve existing profile edit/save/error behavior tests.
- Update the readiness audit only for P1-4 and the recorded task checks.

## Non-goals

- No new routes or router/shell architecture changes.
- No logout reimplementation; Settings remains the owner of logout behavior.
- No notifications entry until its backend/repository is implemented.
- No address-form, orders, settings, auth, Supabase, schema, migration, or RLS
  changes.
- No opportunistic visual redesign of Profile or other pages.

## Allowed paths

- `lib/features/profile/presentation/views/profile_page.dart`
- `test/features/profile`
- `docs/audits/application-readiness.md`

## Acceptance criteria

- A loaded authenticated Profile page visibly exposes Orders, Addresses, and
  Settings/Logout destinations with clear labels and icons/semantics.
- Tapping each entry navigates to the existing exact `AppRoutes` destination.
- Back navigation returns to the Profile tab without losing shell context.
- Navigation entries remain usable and do not accidentally submit or reset the
  profile edit form.
- Loading and error states remain unchanged and do not show unusable account
  links.
- Widget tests cover all three taps plus preservation of profile editing.
- No notification placeholder link is added.

## Required quality gates

- Format changed Dart files.
- `flutter analyze`
- `flutter test test/features/profile`
- `flutter test`
- `python3 scripts/automation.py policy-check`

