# Supabase — Badminton Store

Local Supabase database foundation for the Flutter badminton shop.

## Layout

```
supabase/
  config.toml
  migrations/     # ordered SQL migrations (source of truth)
  seed.sql        # demo catalog
  import/         # CSV templates + import README
  tests/database/ # executable constraint / privilege / checkout regressions
  README.md
```

## Prerequisites

- Supabase CLI (`supabase --version`) — acceptance for Data API grants uses CLI 2.111+
- Docker Desktop (required for `supabase start` / `db reset`)

A standalone CLI binary may live at `.tools/supabase` when Homebrew install is blocked.

## Common commands

```bash
# From repo root
./.tools/supabase start          # or: supabase start
./.tools/supabase db reset       # apply migrations + seed (local disposable only)
./.tools/supabase migration list
./.tools/supabase db lint
./.tools/supabase status
```

Never run destructive resets against a linked remote production project.
Apply reviewed migrations to the linked remote only after PR approval/merge via
the established migration workflow.

## Explicit Data API grants (TASK-008)

Migration `*_explicit_data_api_grants.sql` removes residual/implicit table and
view privileges from `PUBLIC` / `anon` / `authenticated`, then grants an
enumerated least-privilege matrix so fresh Supabase CLI 2.111+ projects reach
existing RLS policies instead of failing at the grant layer.

**Grants vs RLS:** table/column/function privileges decide whether a role can
attempt an operation; RLS policies decide which rows succeed. Customers,
staff, and admins all use PostgreSQL role `authenticated`. Staff/admin
catalog, inventory, and order write grants therefore exist on `authenticated`,
while `public.is_staff_or_admin()` / `public.is_admin()` read trusted
`public.profiles.role` (never JWT/user metadata) to authorize those writes.

Highlights:

- `anon`: SELECT on safe catalog tables/views only; column-level SELECT on
  `product_variants` excluding `cost_price`; no customer/order/inventory access
- `authenticated`: catalog-safe reads; own profile/address/favorite/cart flows;
  own order history reads; staff DML grants paired with existing RLS
- `service_role`: explicit ALL on application tables/views for trusted backend
  (never ship this key to Flutter)
- Function contracts from TASK-002/004/007 are restated (public catalog RPCs,
  `checkout_cod` authenticated-only, trigger helpers service_role-only)

`product_catalog.has_stock` uses `get_variant_availability` so public catalog
reads do not require raw `inventory` SELECT.

## Local database regressions

Obtain `DATABASE_URL` from `supabase status` (local DB URL). Run after
`supabase db reset` against the disposable local stack only. If host `psql`
is unavailable, pipe each file into the local DB container:

`docker exec -i supabase_db_Badminton-Store psql -U postgres -d postgres -v ON_ERROR_STOP=1 < path/to/file.sql`

Complete local test order:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/00_constraints.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/02_product_variant_cost_price.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/03_trusted_cod_checkout.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/04_trigger_function_execute.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/05_explicit_data_api_grants.sql
bash supabase/tests/database/03_trusted_cod_checkout_concurrency.sh
```

`01_rls_checklist.sql` remains a comment checklist, not an executable suite.

### Explicit grants suite (TASK-008)

`05_explicit_data_api_grants.sql` asserts grant-layer privileges separately from
role-switched RLS behavior: anon catalog-only matrix, authenticated customer
CRUD + cross-user denial, staff/admin workflows under trusted `profiles.role`,
forged JWT role denial, `cost_price` column lockdown, and function EXECUTE
contracts.

### Trigger-helper EXECUTE contract (TASK-007)

Internal trigger helpers are not client RPCs. Migration
`*_lock_down_trigger_function_execute.sql` revokes `EXECUTE` from `PUBLIC`,
`anon`, and `authenticated`, and grants `EXECUTE` only to `service_role` for:

- `public.prevent_profile_privilege_escalation()`
- `public.assign_order_number()`
- `public.record_order_status_change()`
- `public.validate_product_image_variant()` (audit: trigger-only helper with
  default `PUBLIC EXECUTE`; referenced solely by
  `product_images_validate_variant`)

Trigger behavior is unchanged: profile self-updates still cannot escalate
`role` / `is_active`; order insert/status writes still assign numbers and
append history. Direct client `SELECT public.<helper>()` must fail with
SQLSTATE `42501`.

Excluded from this lockdown (intentional or already controlled):
`set_updated_at`, `handle_new_user_profile`, `cart_items_enforce_active_cart`,
`generate_order_number`, policy helpers, and public RPCs.

## Flutter env

Use publishable/anon key only:

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Never put `service_role` in Flutter.

## Next steps

1. Install Docker + CLI 2.111+
2. `supabase db reset`
3. Run the local database regressions above
4. Verify `product_catalog` view returns active products
