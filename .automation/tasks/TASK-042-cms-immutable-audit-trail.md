# TASK-042 — Immutable CMS privileged audit trail

Risk: high

Status: complete

## Objective

- Deliver roadmap Milestone 3 **TASK-038** (immutable audit trail for privileged
  changes) as automation **TASK-042**.
- Introduce one canonical append-only `cms_privileged_audit_events` ledger fed
  transactionally from trusted CMS mutation sources across catalog, inventory,
  media, orders, and staff management.
- Add an admin-only `/dashboard/audit` Server Component explorer with bounded
  cursor pagination, filters, sanitized failures, and fail-closed metadata
  mapping.

## Scope

- One CLI-created migration:
  `cms_privileged_audit_events`, trusted append helper, immutability triggers,
  source-table audit triggers, and `list_cms_privileged_audit_events`.
- Capture semantic events from:
  - category, brand, product, variant writes (staff/admin RLS paths)
  - `inventory_history` adjustments
  - `order_status_history` staff transitions (exclude checkout seed rows)
  - `staff_management_events` (including invitation finalize actor)
  - product media insert/update/delete
- Actor identity from `auth.uid()` or immutable trusted source columns only.
- Allowlisted metadata per entity/action; no secrets, tokens, addresses, phone
  numbers, customer notes, raw payloads, or `cost_price`.
- Admin-only CMS audit page, navigation, mapper validation, and focused tests.
- DB/RLS/grant/immutability/PII exclusion regressions plus updates to `01`, `04`,
  and `05` suites and CMS/docs/security/schema references.

## Non-goals

- Flutter commands, files, or CI jobs.
- Replacing domain-specific history tables (`inventory_history`,
  `order_status_history`, `staff_management_events`).
- Logging customer checkout or anonymous catalog reads.
- Remote migration application, deployment, or service-role keys in the CMS bundle.

## Allowed paths

- `cms/src/app/dashboard/audit/**`
- `cms/src/features/audit/**`
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
- `.automation/tasks/TASK-042-cms-immutable-audit-trail.md`

## Required quality gates

- Discover Supabase CLI commands via `--help`
- `supabase db reset` (local disposable only)
- `supabase migration list --local`
- `supabase db lint` when supported
- Relevant `01`, `04`, `05`, and `14_cms_privileged_audit_trail.sql`
- `cd cms && npm run format:check`
- `cd cms && npm run lint`
- `cd cms && npm run typecheck`
- `cd cms && npm test -- --run`
- `cd cms && npm run build`
- Do not run Flutter commands
- `git diff --check`
- `python3 scripts/automation.py policy-check`
