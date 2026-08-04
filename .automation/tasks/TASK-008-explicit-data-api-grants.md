# TASK-008 — Declare explicit least-privilege Data API grants

Risk: high

## Objective

Add a new migration that makes the intended `anon`, `authenticated`, and
`service_role` table/view/function privileges explicit so fresh Supabase 2026+
projects reach the existing RLS policies instead of failing at the grant layer.
Preserve the TASK-002 `cost_price` column restriction and trusted checkout
boundary.

## Scope

- Create the migration with `supabase migration new explicit_data_api_grants`.
- Derive minimum grants from existing Flutter repository operations, RLS
  policies, Storage policies, and RPC contracts; do not restore blanket default
  privileges.
- `anon`: catalog-safe reads and intentionally public RPC/view access only.
- `authenticated`: catalog-safe reads; own profile/address/favorite/cart/cart
  item operations; own order/history reads; staff/admin operations must remain
  constrained by existing RLS predicates.
- Do not grant customers direct trusted order creation, order-item creation,
  inventory writes, total/payment/status bypasses, or `cost_price` reads.
- Preserve explicit function contracts from TASK-002/004/007.
- Add executable grant-layer + representative RLS regressions and update docs.

## Allowed paths

- `supabase/migrations`
- `supabase/tests/database/05_explicit_data_api_grants.sql`
- `supabase/README.md`
- `docs/audits/application-readiness.md`

## Acceptance criteria

- Fresh `supabase start && supabase db reset` works with CLI 2.111+ defaults.
- Required table privileges are asserted independently from RLS behavior.
- Anon can read only active safe catalog surfaces and cannot write.
- Authenticated customer cart/address/favorite flows reach and obey RLS.
- Cross-user access remains denied.
- Staff/admin existing catalog/inventory/order workflows retain required table
  grants but are still authorized by trusted profile role through RLS.
- `product_variants.cost_price` remains unreadable to public roles.
- Direct customer writes to orders/order_items/inventory and protected order
  fields remain unavailable.
- Existing checkout and concurrency regressions pass.
- No deployed migration is edited and no remote mutation occurs before merge.

## Required quality gates

- `supabase --version`
- `supabase stop --no-backup` (local disposable only, if needed)
- `supabase start`
- `supabase db reset`
- Execute database suites `00`, `02`, `03`, `04`, and new `05`
- `bash supabase/tests/database/03_trusted_cod_checkout_concurrency.sh`
- `supabase db lint`
- `flutter analyze`
- `flutter test`
- `python3 scripts/automation.py policy-check`

