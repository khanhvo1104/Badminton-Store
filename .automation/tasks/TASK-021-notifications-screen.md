# TASK-021 — Build the in-app notifications screen

Risk: medium

## Objective

- Replace the Notifications placeholder with a tested Riverpod/MVVM screen for private notification history, pagination, refresh, and read-state actions using the TASK-020 repository.

## Scope

- Add immutable Notifications presentation state and an auto-disposed StateNotifier/ViewModel.
- Load the first page, load subsequent pages, refresh from page one, mark one notification read, and mark all notifications read.
- Replace `NotificationsPage` with accessible loading, error, empty, populated, and pagination states.
- Add network-free ViewModel and widget tests through repository/provider overrides.

## Non-goals

- Do not change repositories, entities, schema, migrations, RLS, grants, seed data, Supabase configuration, or remote data.
- Do not add Realtime, push notifications, device permissions/tokens, notification preferences, background work, email/SMS, Edge Functions, cron, deep-link payload navigation, or staff tooling.
- Do not add notification creation/deletion or update owner/content/type/payload/timestamps.
- Do not redesign unrelated screens, routes, navigation, theme, or shared architecture.

## Allowed paths

- `lib/features/notifications/presentation/`
- `test/features/notifications/`
- `.automation/backlog.json`

## Acceptance criteria

- ViewModel initial load requests page 1 with a fixed page size of 20, exposes loading/data/empty/failure states, and never exposes raw backend, SQL, or exception text to the UI.
- Pagination requests each next page at most once, appends without replacing existing items, suppresses duplicate IDs, preserves repository order, and stops when a page contains fewer than 20 items.
- Pagination failure keeps already loaded items visible, exposes sanitized retry feedback, and permits a later retry of the same page.
- Pull-to-refresh requests page 1, replaces stale items on success, resets pagination metadata, and preserves existing content with sanitized feedback if refresh fails.
- `markRead(id)` is ignored while the same mutation is already in flight; success updates that item to read locally and failure leaves it unchanged with sanitized feedback.
- `markAllRead()` is guarded against duplicate mutation; success marks every loaded item read locally and failure leaves them unchanged with sanitized feedback.
- Mutation controls are disabled only as needed while work is in flight; loading-more state is visually represented without blocking the current list.
- Page app bar is titled `Notifications` and offers a clearly labelled “mark all read” action only when at least one loaded item is unread.
- Empty, full-screen loading, full-screen error with retry, populated list, unread/read styling, type icon, title, body, and localized timestamp are rendered with stable widget keys suitable for tests.
- Tapping an unread notification calls `markRead`; tapping an already-read item does not issue another repository update. No payload-driven navigation is introduced.
- Pull-to-refresh works for empty and populated states using always-scrollable physics; reaching the list end can request the next page without repeated calls during an active load.
- ViewModel lifecycle checks prevent state updates after disposal, and action feedback can be consumed/cleared so snackbars are not replayed on rebuild.
- Tests cover initial success/empty/failure, sanitized errors, pagination append/dedup/end/failure-retry, refresh success/failure, both mutation success/failure/duplicate guards, and core widget states/interactions.
- No direct `SupabaseClient` access, privileged credential, schema change, or remote database mutation is introduced in presentation code.

## Required quality gates

- `dart format --output=none --set-exit-if-changed lib/features/notifications/presentation test/features/notifications`
- `flutter analyze`
- `flutter test test/features/notifications`
- `flutter test`
- `git diff --check`
- `python3 scripts/automation.py policy-check`
