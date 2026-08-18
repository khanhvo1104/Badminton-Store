# TASK-037 — Build CMS inventory adjustments

Risk: high

## Objective

- Replace the `/dashboard/inventory` placeholder with a production CMS
  inventory explorer and a per-variant atomic adjustment flow.
- Add immutable inventory history and a narrow trusted RPC so stock changes
  are validated, serialized, and auditable.
- Preserve checkout reservation, existing inventory RLS/grants, and the
  cost/barcode contract.

## Scope

- Explorer at `/dashboard/inventory`: server-rendered bounded pagination,
  search by product/variant/SKU, stock filters, stable sorting, explicit
  columns only. No `cost_price` or `barcode`.
- Adjustment page at `/dashboard/inventory/[variantId]`: fail-closed add,
  remove, set on-hand, update reorder level, and update allow-backorder.
  Required normalized bounded reason; optional bounded note. Reserved is
  read-only. Route-bound variant ID. Re-authorize before every read/write.
  Cookie-backed user JWT only.
- One CLI-created migration: `inventory_history`, `list_cms_inventory`, and
  `adjust_cms_inventory`.

## Non-goals

- Flutter files, Flutter CI, Flutter analyze/test/build.
- Product media, orders/status transitions, sales dashboard, staff
  management, inventory row deletion, editing reserved quantity.
- Dependency, env, deployment, or remote Supabase migration application.

## Allowed paths

- `cms/src/app/dashboard/inventory/**`
- `cms/src/app/dashboard/dashboard.test.tsx`
- `cms/src/app/dashboard/page.tsx`
- `cms/src/features/inventory/**`
- `cms/src/components/ui/**`
- `cms/src/lib/navigation/dashboard-routes.ts`
- `cms/src/lib/navigation/dashboard-routes.test.ts`
- `cms/src/lib/auth/**`
- `cms/src/lib/errors/**`
- `cms/src/lib/supabase/**`
- `cms/README.md`
- `docs/cms/**`
- `docs/backend/database_schema.md`
- `docs/backend/rls_policies.md`
- `supabase/migrations/**`
- `supabase/tests/database/**`
- `supabase/README.md`
- `.automation/backlog.json`
- `.automation/tasks/TASK-037-cms-inventory-adjustments.md`

## Acceptance criteria

- Explorer columns: product, variant/SKU, on-hand, reserved, available,
  reorder level, allow-backorder, status, updated time. Loading, error,
  empty, and accessibility match CMS patterns.
- Server Actions bind `variantId` from the validated route argument and never
  choose the mutation target from FormData.
- `list_cms_inventory` is SECURITY INVOKER with empty `search_path`, fixed
  SQL, staff/admin authorization, and no cost/barcode columns.
- `adjust_cms_inventory` is a justified narrow SECURITY DEFINER RPC with
  empty `search_path`, `is_staff_or_admin()` authorization, `auth.uid()`
  actor, inventory lock/serialize, same-transaction history insert, reserved
  invariant, overflow/negative rejection, and minimal return.
- History is staff/admin readable; direct authenticated insert/update/delete
  are closed. Rows are immutable via grants, RLS, constraints, and a mutation
  trigger.
- CMS tests cover auth-before-read/write, route ID binding, query bounds,
  fail-closed parsing, exact integers, sanitized errors, UI states, and
  adjustment revalidation/redirect.
- DB tests cover staff/admin success; anon/customer/inactive/forged denial;
  direct history I/U/D denial; invalid/cross IDs; bounds; no negative/overflow;
  reserved invariant; missing row; rollback; immutability; minimal return;
  concurrency without lost updates.

## Required quality gates

- Discover Supabase CLI commands via `--help`; create migration via
  `supabase migration new`
- Apply locally; `supabase migration list --local`
- Relevant `01`, `02`, `05`, `07` and new/extended DB tests plus concurrency
- `cd cms && npm ci` if necessary
- `cd cms && npm run format:check`
- `cd cms && npm run lint`
- `cd cms && npm run typecheck`
- `cd cms && npm test -- --run`
- `cd cms && npm run build`
- Do not run Flutter commands
- `git diff --check`
- `python3 scripts/automation.py policy-check`
