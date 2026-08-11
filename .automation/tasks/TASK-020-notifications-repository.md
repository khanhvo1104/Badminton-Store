# TASK-020 — Wire the Flutter notifications repository

Risk: medium

## Objective

- Implement and wire the authenticated Flutter notifications repository against the least-privilege Supabase backend from TASK-019, with network-free regression coverage.

## Scope

- Add a Supabase-backed `NotificationRepository` implementation for paginated history, unread count, marking one notification read, and marking all notifications read.
- Wire the implementation through the existing Riverpod provider.
- Add narrow injectable query seams only where needed for deterministic offline tests.
- Preserve the existing domain interface and entity unless a minimal compatibility correction is required to map the documented database contract safely.

## Non-goals

- Do not change schema, migrations, RLS, grants, seed data, remote Supabase data, or Supabase project configuration.
- Do not build the Notifications page/ViewModel, badges, Realtime subscriptions, push notifications, preferences, email/SMS delivery, Edge Functions, cron jobs, or staff tooling.
- Do not add customer notification creation/deletion or updates to owner, content, type, payload, or timestamps.
- Do not use a service-role/secret key, user-editable metadata, or weaken client/server authorization boundaries.
- Do not refactor unrelated repositories, screens, navigation, or documentation.

## Allowed paths

- `lib/features/notifications/`
- `test/features/notifications/`
- `.automation/backlog.json`

## Acceptance criteria

- The production repository uses the configured `SupabaseClient` and requires an authenticated user before every operation; unauthenticated calls return `UnauthorizedException` failures without invoking database seams.
- History validates `page >= 1` and `pageSize >= 1`, computes the inclusive Supabase range correctly, explicitly filters by the current `user_id`, and returns newest-first stable ordering by `created_at DESC, id DESC`.
- History uses an explicit projection containing only the documented notification fields: `id,user_id,title,body,type,is_read,payload,created_at`.
- Row mapping covers all four database type values (`order_update`, `promotion`, `system`, `stock_alert`), UTC/timestamp parsing, read state, and the string payload contract without unsafe casts; malformed required data returns a typed application failure rather than leaking a runtime type error.
- Unread count is explicitly scoped to the authenticated `user_id` and `is_read = false`, uses Supabase exact-count semantics without downloading notification bodies, and returns zero safely when appropriate.
- `markRead(id)` rejects a blank ID, scopes the update to the authenticated owner and requested ID, and sends only `is_read: true`.
- `markAllRead()` scopes the update to the authenticated owner and currently unread rows, and sends only `is_read: true`.
- Every operation maps `PostgrestException` to `DatabaseException` with the database code preserved; auth, validation, and row-mapping failures retain typed application exceptions.
- The Riverpod provider returns `SupabaseNotificationRepository(ref.watch(supabaseClientProvider))`; no placeholder throw remains.
- Tests are network-free and verify auth guards, pagination/range, projection, both stable order clauses, owner/unread filters, exact-count behavior, minimal update payloads, complete mapping, validation, and Postgrest error mapping.
- Existing public repository interface remains compatible and no privileged credential or remote database mutation is introduced.

## Required quality gates

- `dart format --output=none --set-exit-if-changed lib/features/notifications test/features/notifications`
- `flutter analyze`
- `flutter test test/features/notifications`
- `flutter test`
- `git diff --check`
- `python3 scripts/automation.py policy-check`
