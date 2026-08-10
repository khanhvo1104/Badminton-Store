# TASK-007 — Revoke unintended client EXECUTE on trigger helpers

Risk: high

## Objective

Create and apply a new Supabase migration that removes PostgreSQL's default
`PUBLIC EXECUTE` exposure from internal `SECURITY DEFINER` trigger functions,
without changing their trigger behavior. Add an executable regression proving
that client roles cannot call them and that their owning triggers still work.

## Scope

- Use `supabase migration new lock_down_trigger_function_execute` to create the
  migration; never edit a deployed migration.
- Revoke direct execution from `PUBLIC`, `anon`, and `authenticated` for:
  - `public.prevent_profile_privilege_escalation()`
  - `public.assign_order_number()`
  - `public.record_order_status_change()`
- Preserve required trusted operational access only when justified (normally
  `service_role`); trigger execution itself must continue working.
- Audit other application-owned trigger/helper functions for the same default
  grant. Include an additional function only when the migration history proves
  it is an internal non-client API with unintended exposure.
- Add a role-switched local SQL regression for exact function privileges and
  trigger behavior (profile escalation still blocked, order number/history
  triggers still fire through authorized server-side writes).
- Update security/readiness documentation with verified results.

## Security boundaries

- Do not change function bodies, RLS policies, table grants, checkout behavior,
  inventory logic, or Flutter code merely to make tests pass.
- Do not grant trigger helpers to `anon` or `authenticated`.
- Do not rely on user-editable metadata for authorization.
- Do not print credentials, JWTs, service-role keys, cost prices, or sensitive
  fixture contents.
- All development verification targets the disposable local Supabase stack.
  Apply the reviewed migration to the already linked remote project only after
  PR approval/merge, using the established migration workflow.

## Allowed paths

- `supabase/migrations`
- `supabase/tests/database/04_trigger_function_execute.sql`
- `supabase/README.md`
- `docs/audits/application-readiness.md`

## Acceptance criteria

- A new migration exists; no deployed migration is edited.
- `has_function_privilege` proves `PUBLIC`/`anon`/`authenticated` cannot execute
  each protected helper and trusted access matches the documented contract.
- Calling protected helpers as client roles fails with the expected privilege
  SQLSTATE rather than an arbitrary function error.
- Profile and order trigger regressions prove revocation did not disable normal
  trigger execution.
- `supabase db reset` succeeds from scratch and the regression passes.
- No unrelated schema diff or scope creep is introduced.

## Required quality gates

- `supabase --version`
- `supabase db reset`
- Execute `00_constraints.sql`
- Execute `02_product_variant_cost_price.sql`
- Execute `03_trusted_cod_checkout.sql`
- Execute `04_trigger_function_execute.sql`
- `bash supabase/tests/database/03_trusted_cod_checkout_concurrency.sh`
- `supabase db lint`
- `flutter analyze`
- `flutter test`
- `python3 scripts/automation.py policy-check`

