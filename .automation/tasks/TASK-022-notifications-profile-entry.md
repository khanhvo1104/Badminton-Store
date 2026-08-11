# TASK-022 — Surface notifications and unread count in Profile

Risk: medium

## Objective

- Add an accessible Notifications entry to the authenticated Profile account hub and surface the owner-scoped unread count from the existing repository without making Profile depend on badge availability.

## Scope

- Add a narrowly scoped auto-disposed Riverpod provider/controller for `NotificationRepository.unreadCount()` suitable for Profile consumption and explicit refresh.
- Add a Notifications account entry to `ProfilePage` that navigates to the existing `/notifications` route.
- Render a compact unread badge, refresh it after returning from Notifications, and add network-free provider/widget/navigation tests.

## Non-goals

- Do not change notification repository/entity contracts, schema, migrations, RLS, grants, seed data, Supabase configuration, or remote data.
- Do not add Realtime, polling, push notifications, app-icon badges, bottom-navigation badges, device permissions/tokens, preferences, background work, or notification creation/deletion.
- Do not redesign Profile, Notifications, routing, shared navigation, or unrelated account entries.
- Do not display raw backend errors or block Profile/navigation when unread count fails.

## Allowed paths

- `lib/features/notifications/di/`
- `lib/features/notifications/presentation/`
- `lib/features/profile/presentation/views/profile_page.dart`
- `test/features/notifications/`
- `test/features/profile/profile_page_test.dart`
- `.automation/backlog.json`

## Acceptance criteria

- An auto-disposed unread-count provider invokes `notificationRepositoryProvider.unreadCount()` once per active lifecycle and converts repository success to a non-negative count.
- Repository failure produces a sanitized/best-effort badge state: Profile stays loaded, the Notifications entry remains enabled, no snackbar/raw SQL/backend/exception text is shown, and the badge is omitted.
- `ProfilePage` adds a stable `profile_account_notifications` entry labelled `Notifications` with a notifications icon and navigates using `context.push(AppRoutes.notifications)`.
- The entry awaits navigation completion and invalidates/reloads unread count after returning so read actions performed on Notifications are reflected.
- Count zero and loading/error states omit the badge; positive counts render a compact accessible badge; counts above 99 render `99+` while retaining the full unread count in semantics.
- Badge semantics identify the unread notification count without causing duplicate/confusing screen-reader labels; the account entry remains a button labelled Notifications.
- Existing Orders, Addresses, Settings, profile edit/save behavior, route protection, and navigation state remain unchanged.
- Provider tests cover success, zero, failure sanitization/best-effort behavior, and refresh/invalidation; widget tests cover loading/zero/positive/99+/failure states, navigation, and refreshed count after route return.
- Tests use repository/provider overrides and no live Supabase/network access.
- Presentation code uses only the existing owner-scoped repository; no direct `SupabaseClient`, privileged credential, schema change, or remote database mutation is introduced.

## Required quality gates

- `dart format --output=none --set-exit-if-changed lib/features/notifications lib/features/profile/presentation/views/profile_page.dart test/features/notifications test/features/profile/profile_page_test.dart`
- `flutter analyze`
- `flutter test test/features/notifications test/features/profile/profile_page_test.dart`
- `flutter test`
- `git diff --check`
- `python3 scripts/automation.py policy-check`
