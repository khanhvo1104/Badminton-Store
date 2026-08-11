# TASK-026 — Add the CMS database security contract

Risk: high

## Objective

- Add a least-privilege database contract that lets active staff/admin CMS
  sessions read product variant cost prices without exposing them to customers
  or weakening the existing catalog, RLS, Storage, and column-grant boundaries.

## Scope

- Use `supabase migration new cms_variant_cost_contract` to create one new
  migration; never edit a deployed migration.
- Add one narrowly scoped RPC for reading variant IDs and cost prices for an
  explicitly requested product.
- Give the RPC an explicit function privilege contract and trusted
  profile-based authorization.
- Add a focused executable database regression for the RPC and relevant CMS
  catalog/Storage authorization matrix.
- Update Supabase and CMS security documentation with the resulting contract.

## Security contract

- The RPC is `public.get_staff_variant_costs(p_product_id uuid)` and returns
  only `variant_id uuid` and `cost_price numeric(14, 2)` for variants belonging
  to that exact product, in deterministic `sort_order, id` order.
- It may use `SECURITY DEFINER` only because the shared PostgreSQL role
  `authenticated` intentionally lacks `SELECT(cost_price)`. It must be `STABLE`,
  use `SET search_path = ''`, fully qualify every database reference, and
  explicitly validate a non-null `auth.uid()` against an active trusted
  `public.profiles` row whose role is `staff` or `admin`.
- Missing, inactive, customer, forged-metadata, and unsupported profiles must
  receive the same generic authorization failure. A null product ID must fail
  with a stable generic validation error. Errors must not reveal SQL, schema,
  profile, token, credential, or product data.
- Revoke default execution from `PUBLIC` and all public API roles, then grant
  only `authenticated` execution. Do not grant the function to `anon`; do not
  rely on the PostgreSQL role alone because customers also use
  `authenticated`.
- Existing direct column access remains unchanged: neither `anon` nor
  `authenticated` receives table-wide SELECT or `SELECT(cost_price)` on
  `public.product_variants`. Service-role/direct trusted backend access remains
  unchanged.

## Non-goals

- Do not add CMS UI, product CRUD pages, generated TypeScript types, Server
  Actions, Route Handlers, service-role clients, or client-side cost caching.
- Do not add a generic SQL/table proxy, accept arbitrary filters/columns, return
  full variant rows, or expose cost price through a view/public catalog query.
- Do not redesign existing catalog/Storage policies or broaden grants/default
  privileges for `PUBLIC`, `anon`, or `authenticated`.
- Do not authorize from `user_metadata`, `app_metadata`, request parameters, or
  UI state, and do not trust a caller-supplied user/role ID.
- Do not edit existing deployed migrations or unrelated application files.
- Do not apply migrations to a linked remote Supabase project in this
  implementation PR; verification uses the disposable local stack. Remote
  application happens only after review and merge through the established
  migration workflow.

## Allowed paths

- `supabase/migrations/`
- `supabase/tests/database/07_cms_security_contract.sql`
- `supabase/README.md`
- `docs/cms/security.md`
- `docs/backend/rls_policies.md`
- `docs/backend/database_schema.md`
- `.automation/backlog.json`

## Acceptance criteria

- A new CLI-generated migration creates exactly the RPC contract above without
  altering or duplicating existing tables, RLS policies, or deployed migrations.
- The function has a fixed empty search path, fully qualified references,
  explicit caller authorization, a generic failure surface, deterministic
  output, and no dynamic SQL.
- Function privileges are explicit: `PUBLIC`, `anon`, and `service_role` do not
  have EXECUTE; `authenticated` does. Customers still cannot obtain data
  because the function checks the active trusted profile row internally.
- The function does not return full variant rows, product/customer data, or any
  field other than variant ID and nullable cost price for the requested product.
- `07_cms_security_contract.sql` runs in a transaction and rolls back all
  fixtures. It proves anonymous/null-subject denial; customer, inactive staff,
  missing profile, unsupported role, and forged metadata denial; active staff
  and admin success; exact product scoping; deterministic result ordering; null
  product validation; and the explicit EXECUTE matrix.
- The focused regression also proves the existing `cost_price` column remains
  unavailable to `anon`/`authenticated`, customers cannot mutate catalog or
  catalog Storage objects, and active staff/admin retain their existing scoped
  catalog and Storage capabilities. It must not print cost values, JWTs,
  credentials, or internal error details.
- Existing full database suites pass after a fresh local reset, and database
  lint/advisors report no new warning caused by the migration.
- Documentation explains how the later CMS product-management task combines
  normal user-scoped variant reads with this cost-only RPC and why a
  service-role browser/server client is unnecessary.
- No linked remote project is mutated by the implementation PR.

## Required quality gates

- `supabase --version`
- `supabase db reset`
- Execute every database regression listed in `supabase/README.md`, including
  the new `supabase/tests/database/07_cms_security_contract.sql`, using the
  established local psql command or Docker fallback
- `supabase db lint --local --level warning`
- `supabase migration list --local`
- `git diff --check`
- `python3 scripts/automation.py policy-check`
