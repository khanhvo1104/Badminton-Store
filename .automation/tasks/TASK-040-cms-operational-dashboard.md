# TASK-040 — Build CMS operational dashboard

Risk: high

Status: complete

## Objective

- Replace the `/dashboard` placeholder with a production operational overview for
  staff and admins: sales signals and low-stock alerts from one trusted RPC.
- Keep monetary metrics currency-aware with no cross-currency aggregation.
- Preserve existing RLS/grants, cost/PII contracts, and CMS auth boundaries.

## Scope

- One CLI-created migration:
  `get_cms_operational_dashboard(p_range_days integer default 30)`.
- STABLE SECURITY INVOKER RPC with empty `search_path`,
  `public.is_staff_or_admin()` authorization, bounded arguments (7/30/90 days),
  revoked PUBLIC/anon execute, explicit authenticated/service_role grants.
- Fixed return contract:
  - global counts: total orders, delivered orders, open fulfillment backlog,
    status breakdown for placed_at window
  - monetary metrics grouped by `currency_code` only (no mixed totals)
  - `daily_series_by_currency` with independent UTC zero-filled series per
    currency
  - bounded low-stock variants (max 10) with deterministic urgency sort
- Server-rendered `/dashboard` overview with URL range selector, accessible
  semantic HTML/CSS visualization, loading/error/empty states, links to orders
  and inventory filters.
- Focused CMS mapper/query/page tests and DB/RLS/grant regressions including
  VND + USD fixtures proving no cross-currency summation or mislabeling.

## Non-goals

- Flutter files or Flutter CI/analyze/test/build.
- Chart libraries, new npm dependencies, API routes, or unnecessary Client
  Components.
- Payment mutation, staff management, audit trail, deployment, or remote
  migration application.

## Metric definitions

- **Window:** `[UTC now - range_days, UTC now]` for placed_at metrics.
- **Total orders:** count of orders with `placed_at` in the window.
- **Gross order value:** sum of `grand_total` per `currency_code` for orders
  in the window where status is not `cancelled` or `returned`. Label as gross
  order value, not recognized revenue. Never sum across currencies.
- **Delivered orders:** count with `status = delivered` and `placed_at` in the
  window.
- **Open fulfillment backlog:** current global count in
  `pending|confirmed|preparing|shipping` (not windowed).
- **Status breakdown:** order counts by status for the placed_at window.
- **Daily series:** per currency, every UTC calendar day in the window with
  zero-filled `order_count` and `gross_order_value` (cancelled/returned
  excluded from gross only).
- **Low stock:** up to 10 variants where signed
  `available = quantity_on_hand - quantity_reserved` is `<= reorder_level`;
  include `allow_backorder` rows; include inactive catalog rows when inventory
  exists.
- **Daily series contract:** `range_days + 1` consecutive UTC dates from
  `window_start` through `window_end` dates, independently zero-filled per
  currency; gross and daily currency sets must match exactly; more than 20
  window currencies raises `invalid request`.

## Allowed paths

- `cms/src/app/dashboard/page.tsx`
- `cms/src/app/dashboard/page.test.tsx`
- `cms/src/app/dashboard/dashboard.test.tsx`
- `cms/src/features/operational-dashboard/**`
- `cms/src/lib/navigation/dashboard-routes.ts`
- `cms/src/lib/navigation/dashboard-routes.test.ts`
- `cms/README.md`
- `docs/cms/**`
- `docs/backend/database_schema.md`
- `docs/backend/rls_policies.md`
- `supabase/migrations/**`
- `supabase/tests/database/**`
- `supabase/README.md`
- `.automation/backlog.json`
- `.automation/tasks/TASK-040-cms-operational-dashboard.md`

## Required quality gates

- Discover Supabase CLI commands via `--help`
- `supabase db reset` (local disposable only)
- `supabase migration list --local`
- `supabase db lint` when supported
- Relevant `01`, `05`, and `12_cms_operational_dashboard.sql`
- `cd cms && npm run format:check`
- `cd cms && npm run lint`
- `cd cms && npm run typecheck`
- `cd cms && npm test -- --run`
- `cd cms && npm run build`
- Do not run Flutter commands
- `git diff --check`
