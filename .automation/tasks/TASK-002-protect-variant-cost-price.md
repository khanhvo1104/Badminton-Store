# TASK-002 — Protect product variant cost price

Risk: high

## Objective

Close the verified P0 confidentiality gap that allows public API roles to read
`public.product_variants.cost_price`, while preserving the current public product
detail experience.

## Scope

- Create a new Supabase migration with `supabase migration new`; never edit an
  existing migration.
- Restrict `anon` and `authenticated` Data API access so `cost_price` cannot be
  selected. This includes staff/admin users authenticated through Flutter,
  because they share the PostgreSQL `authenticated` role with customers.
- Preserve `cost_price` access only for trusted backend operations using
  `service_role` or direct database credentials. The repository currently has
  no approved staff/admin Flutter workflow that requires direct cost access.
- Keep RLS enabled and retain the active-product/active-variant row visibility
  boundary.
- Replace wildcard variant selection in the Flutter product repository with an
  explicit safe column list.
- Add executable database/security regression coverage proving public roles
  cannot read `cost_price` and can still read the safe public variant fields.
- Update the readiness audit only to mark P0-1 resolved and record the exact
  migration/test paths; do not rewrite unrelated findings.

## Acceptance criteria

- `anon` and ordinary `authenticated` clients cannot select
  `product_variants.cost_price` directly through the Data API.
- Public product detail can still load all variant fields needed by the current
  Flutter mapper and UI.
- Trusted backend access through `service_role`/direct database credentials is
  preserved; Flutter clients, including staff/admin JWT sessions, have no direct
  `cost_price` access.
- No existing migration is modified.
- A new migration and executable regression test demonstrate the intended
  column privileges and public read behavior.
- Changed Dart files are formatted; `flutter analyze`, `flutter test`, automation
  policy checks, and applicable local Supabase checks pass.
- No remote Supabase command is run and no environment or secret file is read.

## Allowed paths

- `supabase/migrations`
- `supabase/tests/database`
- `lib/features/product/data/repositories/supabase_product_repository.dart`
- `test/features/product`
- `docs/audits/application-readiness.md`

## Forbidden actions

- Do not edit deployed migration files.
- Do not apply, push, reset, seed, or otherwise mutate a local or remote
  Supabase database unless the task's existing quality command clearly targets
  an already configured disposable local test instance.
- Do not expose `cost_price` through a view, RPC, Flutter model, log, fixture, or
  client response.
- Do not invent an authenticated staff exception, view, or RPC. A future admin
  workflow requiring cost data must be a separately reviewed backend task.
- Do not add a service-role or secret key to Flutter or tests.
- Do not weaken RLS or grant broad table access to solve a permission error.
- Do not implement checkout or unrelated commerce features.
