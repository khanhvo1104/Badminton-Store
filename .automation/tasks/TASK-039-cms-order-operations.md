# TASK-039 — Build CMS order operations

Risk: high

## Objective

- Replace the orders placeholder with production staff/admin CMS order
  search, detail, and trusted status transitions.
- Enforce allowed transitions and inventory side effects in one atomic
  database RPC with row locks and `auth.uid()` as actor.
- Preserve checkout reservations, existing order RLS/grants, immutable
  totals/snapshots, and the cost/barcode contract.

## Scope

- Orders navigation and protected `/dashboard/orders` list plus
  `/dashboard/orders/[orderId]` detail with loading/error/not-found.
- Server-side pagination, stable sorting, bounded filters/search. Search
  order number plus recipient name/phone with wildcard-stripped literals.
  Filters for order status, payment status, and placed date range.
- Detail shows trusted totals, safe recipient/shipping snapshot fields,
  item snapshots, and append-only status history. No unrelated profile/
  auth fields or protected catalog fields.
- Narrow transition Server Action with confirmation, route-bound order ID,
  optional bounded staff note, independent authorization, sanitized errors,
  revalidation, and tests.
- One CLI-created migration: `list_cms_orders` and
  `transition_cms_order_status`, plus history-trigger note support via a
  transaction-local setting so history is written exactly once.

## Non-goals

- Flutter files, Flutter CI, Flutter analyze/test/build.
- Payment status mutation, restocking on return, sales dashboard, staff
  management, editing totals/items/shipping snapshots.
- Dependency, env, deployment, or remote Supabase migration application.

## Allowed paths

- `cms/src/app/dashboard/orders/**`
- `cms/src/app/dashboard/dashboard.test.tsx`
- `cms/src/app/dashboard/page.tsx`
- `cms/src/features/orders/**`
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
- `docs/architecture/006-nextjs-cms.md`
- `supabase/migrations/**`
- `supabase/tests/database/**`
- `supabase/README.md`
- `.automation/backlog.json`
- `.automation/tasks/TASK-039-cms-order-operations.md`

## Acceptance criteria

- Transition graph (unless a stricter existing contract appears):
  pending→confirmed|cancelled; confirmed→preparing|cancelled;
  preparing→shipping|cancelled; shipping→delivered; delivered→returned;
  cancelled/returned terminal. Payment status is read-only.
- Cancellation from pre-shipping cancellable states releases each item
  reservation. Delivered consumes each item quantity from both
  `quantity_reserved` and `quantity_on_hand`. Returned does not auto-restock.
- Validate non-null variants/inventory and sufficient reserved/on-hand
  before inventory mutation. Serialize with an order row lock.
- History is written exactly once via the existing status-history trigger;
  staff notes use a transaction-local setting. `cancelled_at` is set
  consistently. Totals/items/shipping snapshots are never edited.
- Revoke direct `UPDATE` on `public.orders` from `authenticated`. Status
  changes go only through `transition_cms_order_status`, a narrow SECURITY
  DEFINER RPC with empty `search_path`, `is_staff_or_admin()` + `auth.uid()`,
  row/inventory locks, transition + inventory effects, and minimal return.
  Do not use client-settable GUCs as a trust boundary. Trigger EXECUTE stays
  locked; history remains exactly one row per status change via the existing
  trigger. Test that authenticated staff cannot direct-UPDATE status while
  the RPC succeeds.
- CMS tests cover auth-before-read/write, route ID binding, query bounds,
  confirmation, sanitized errors, UI states, and export-boundary coverage.
- DB tests cover staff/admin success; anon/customer/inactive denial;
  invalid transitions; inventory release/consume; missing variant/inventory;
  history exactly once with note; concurrent same-order transitions;
  grants/RLS regressions.

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
