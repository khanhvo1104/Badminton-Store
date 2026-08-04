# TASK-006 — Build executable RLS, Storage, RPC, and privilege regressions

Risk: high

## Objective

Replace the comment-only `01_rls_checklist.sql` with a deterministic executable
local regression suite that proves the current authorization model for anon,
two independent customers, staff/admin, Storage objects, privileged profile
fields, and public RPC grants. This task verifies deployed migrations; it must
not change schema, policies, grants, functions, triggers, seed data, or remote
Supabase state.

## Scope

- Convert `supabase/tests/database/01_rls_checklist.sql` into executable SQL
  assertions using transaction-local role/JWT switching.
- Add a small shell runner only if needed to execute the SQL safely inside the
  local Supabase database container.
- Use isolated deterministic fixtures and roll them back or clean them up even
  when practical; do not depend on personal/remote users.
- Test grants separately from RLS. Current Supabase defaults increasingly
  require explicit Data API grants; a missing grant must not be mistaken for a
  passing RLS denial.
- Never print passwords, JWTs, API keys, service-role keys, cost prices, or
  sensitive row contents. Assertions may report only scenario names/counts.
- Keep existing TASK-002 cost-price and TASK-004 checkout suites intact; this
  suite complements them rather than duplicating their detailed coverage.

## Required executable scenarios

1. **Baseline security metadata**
   - Every application table in exposed `public` has RLS enabled.
   - Security-invoker expectations for public catalog/availability views remain
     intact where applicable.
   - Expected table/function privileges for `anon`, `authenticated`, and
     `service_role` are asserted explicitly.
2. **Anonymous catalog boundary**
   - Active categories/brands/products and safe active variants are readable.
   - Draft/inactive catalog rows are invisible.
   - Anonymous catalog writes, profiles, addresses, favorites, carts, orders,
     order items/history, and raw inventory access are denied or return zero as
     appropriate; distinguish lack of grant from RLS invisibility.
3. **Customer A vs Customer B isolation**
   - Each customer can read/update their own allowed profile fields and CRUD
     their own addresses, favorites, active cart, and cart items.
   - Cross-user reads/writes/deletes are rejected or affect zero rows.
   - Customers can read only their own orders, order items, and status history.
   - Customers cannot directly insert/update privileged order, order-item,
     inventory, payment, total, status, or ownership fields.
4. **Privilege escalation protection**
   - A customer cannot change `profiles.role`, `is_active`, or another protected
     authorization field through a self update.
   - Authorization derives from trusted profile/app state, never editable
     `user_metadata`.
5. **Staff/admin matrix**
   - Staff/admin can perform only the catalog, inventory, customer/order reads,
     and order workflow writes currently granted by migrations.
   - A plain customer with forged user metadata cannot gain staff/admin access.
   - Preserve any intentional admin-only distinction that exists in migrations.
6. **Storage policies**
   - Public catalog buckets are readable as designed.
   - Anonymous/customer catalog-object writes are denied.
   - Staff/admin catalog-object insert/update/delete behavior is verified.
   - Authenticated avatar reads follow current policy; customer A can write only
     under the owned `<auth.uid()>/...` path and cannot mutate customer B paths.
   - Cover INSERT, SELECT, UPDATE, and DELETE separately so Storage upsert
     prerequisites are not accidentally assumed.
7. **RPC/function exposure**
   - `checkout_cod` remains unavailable to `PUBLIC`/`anon` and executable by
     `authenticated`/`service_role` only.
   - Public catalog search/availability functions retain their intended grants
     and do not expose raw inventory or cost fields.
   - Trigger/helper functions that are not client APIs are not accidentally
     callable by unintended roles.

## Non-goals

- No migration or production policy/grant fix. If a test reveals a real policy
  defect, keep the failing regression, report the exact blocker, and stop for a
  separately approved migration task.
- No remote `supabase db push`, migration repair, SQL execution, data mutation,
  project linking, or dashboard change.
- No Flutter feature work.
- No edits to deployed files under `supabase/migrations/`.

## Allowed paths

- `supabase/tests/database/01_rls_checklist.sql`
- `supabase/tests/database/01_rls_checklist.sh`
- `supabase/README.md`
- `docs/audits/application-readiness.md`

## Acceptance criteria

- The old comment-only checklist is replaced by assertions that exit non-zero
  on any unexpected authorization result.
- Tests set both the Postgres role and transaction-local JWT claims, resetting
  them safely between scenarios.
- Fixtures are deterministic, isolated from seed business rows, and leave the
  disposable local database reusable after a successful run.
- Expected denials validate SQLSTATE/row-count behavior rather than swallowing
  arbitrary exceptions.
- The suite runs successfully from a freshly reset local Supabase stack.
- No secrets or protected values appear in source, command output, or PR body.
- Documentation lists the exact local command and accurately distinguishes
  tests added here from TASK-002 cost-price and TASK-004 checkout tests.

## Required quality gates

- `supabase --version`
- `supabase db reset`
- Execute `supabase/tests/database/00_constraints.sql`
- Execute the new `supabase/tests/database/01_rls_checklist.sql` (or its runner)
- Execute `supabase/tests/database/02_product_variant_cost_price.sql`
- Execute `supabase/tests/database/03_trusted_cod_checkout.sql`
- `bash supabase/tests/database/03_trusted_cod_checkout_concurrency.sh`
- `supabase db lint`
- `flutter analyze`
- `flutter test`
- `python3 scripts/automation.py policy-check`

All database commands must target the disposable local Supabase instance only.

