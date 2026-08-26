# TASK-048 — Open orders from order-update notification taps

Risk: medium

## Objective

- After TASK-047 ships a stable `order_update` payload contract, make tapping
  an order-update notification in Flutter navigate to the existing `/orders`
  route (best-effort deep link without inventing an order-detail screen).

## Scope

- Teach the notifications presentation layer to navigate with
  `context.push(AppRoutes.orders)` when the item type is `orderUpdate`
  (optionally requiring payload `order_id` / `order_number` once TASK-047
  defines them).
- Keep mark-read behavior; do not block navigation on mark-read failure;
  sanitize errors; no raw backend text.
- Add network-free widget/ViewModel tests for tap → `/orders`, non-order
  types unchanged, and mark-read still invoked for unread items as today.

## Non-goals

- Do not implement Flutter order-detail routes, CMS changes, schema,
  migrations, Realtime, push, or new dependencies.
- Do not start until TASK-047’s payload contract is merged (or land behind a
  documented minimal contract that matches TASK-047 exactly).
- Do not change Profile unread badge, repository interface beyond what tap
  handling needs, or auth/router architecture.

## Allowed paths

- `lib/features/notifications/presentation/**`
- `test/features/notifications/**`
- `docs/audits/application-readiness.md`
- `.automation/backlog.json`
- `.automation/tasks/TASK-048-notification-orders-navigation.md`

## Acceptance criteria

- [x] Unread and read `order_update` rows navigate to `AppRoutes.orders` on tap.
- [x] Other notification types do not gain accidental navigation.
- [x] Existing mark-read, pagination, sanitized feedback, and Profile entry
  behavior remain intact.
- [x] Tests use provider/router overrides; no live network/Supabase.

## Required quality gates

- `dart format --output=none --set-exit-if-changed` on changed Dart paths
- `flutter analyze`
- `flutter test test/features/notifications`
- `flutter test`
- `git diff --check`
- `python3 scripts/automation.py policy-check`
