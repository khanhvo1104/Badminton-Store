# TASK-047 — Emit trusted in-app order-update notifications

Risk: high

## Objective

- Close the hollow notifications producer gap: owner-scoped
  `public.notifications` rows must be created by trusted server paths when
  orders are placed or their status changes, so the existing Flutter
  notifications UI can surface real `order_update` content.

## Scope

- Add one new Supabase CLI migration (never edit deployed migrations) that
  inserts a single owner-scoped notification inside the existing trusted
  writers:
  - successful `public.checkout_cod` (order placed → customer `user_id`)
  - successful `public.transition_cms_order_status` (status change → order
    owner `user_id`)
- Use `type = 'order_update'`, non-blank title/body, object-only `payload`
  with stable string keys at least `order_id` and `order_number` (and
  `from_status` / `to_status` on transitions when applicable). No secrets,
  tokens, PII beyond order number already known to the owner, or privileged
  credentials in payload.
- Preserve empty `search_path`, existing authz, inventory/history behavior,
  grants, and RLS. Customers must still lack INSERT/DELETE; writers run only
  inside SECURITY DEFINER trusted functions (or equivalent fail-closed path).
- Extend executable DB regressions (notifications suite and/or checkout +
  order-operations suites) proving: row created for owner; other customers
  cannot see it; customers still cannot INSERT; failure of notification
  insert fails the writer transaction (no silent drop) **or** document and
  test an explicit, reviewed best-effort policy if product chooses otherwise
  (default: fail closed with the writer).
- Update `docs/backend/notifications_security.md` (and readiness pointers if
  needed) for the producer contract.

## Non-goals

- No Flutter UI/navigation changes (TASK-048).
- No CMS compose UI, broadcast, promotions, stock_alert, system spam, Realtime,
  push, email/SMS, Edge Functions, cron, or device tokens.
- No payment-method expansion, RLS weakening, service-role in clients, or
  remote migration apply in the implementation PR.
- No dependency/lockfile/workflow/env/secret changes.

## Allowed paths

- `supabase/migrations/`
- `supabase/tests/database/**`
- `supabase/README.md`
- `docs/backend/notifications_security.md`
- `docs/backend/checkout_security.md`
- `docs/audits/application-readiness.md`
- `.automation/backlog.json`
- `.automation/tasks/TASK-047-trusted-order-notifications.md`

## Acceptance criteria

- [x] After local `db reset`, placing a COD order and transitioning order status
  each create exactly one new owner notification with the contracted payload
  shape (idempotent retry of checkout must not create duplicates beyond the
  existing checkout idempotency rules — assert explicitly).
- [x] Suites covering checkout, order transitions, and notifications remain green;
  grant/RLS inventories still deny customer INSERT/DELETE on notifications.
- [x] Docs describe the producer contract and remain honest that push/Realtime are
  out of scope.
- [x] Diff stays within allowed paths; no secrets.

## Required quality gates

- Discover Supabase CLI via `--help`; `supabase migration new …`
- Local disposable: `supabase db reset` + relevant suites (`03`, `06`, `11`,
  concurrency helpers as applicable) + `01`/`05` grant regressions touched
- `supabase migration list --local`
- `python3 scripts/automation.py policy-check`
- `git diff --check`
- Do not run Flutter/CMS app suites unless a doc-only cross-link requires it
