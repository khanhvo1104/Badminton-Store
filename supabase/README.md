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
bash supabase/tests/database/01_rls_checklist.sh
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/02_product_variant_cost_price.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/03_trusted_cod_checkout.sql
bash supabase/tests/database/03_trusted_cod_checkout_concurrency.sh
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/04_trigger_function_execute.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/05_explicit_data_api_grants.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/06_notifications.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/07_cms_security_contract.sql
```

### RLS / Storage / RPC suite (TASK-006)

Primary invocation (validates the local `supabase_db_*` container first):

```bash
bash supabase/tests/database/01_rls_checklist.sh
```

Equivalent direct pipe when preferred:

```bash
docker exec -i supabase_db_Badminton-Store psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 < supabase/tests/database/01_rls_checklist.sql
```

`01_rls_checklist.sql` is an executable, transaction-wrapped regression (ends in
`ROLLBACK`). It asserts grants independently of RLS, then role-switches with
transaction-local JWT claims for anon catalog boundaries, customer A/B
isolation, privilege-escalation / forged-metadata denial, staff/admin workflows
(trusted `profiles.role`; `is_admin()` distinction only), Storage
SELECT/INSERT/UPDATE/DELETE policies, and RPC EXECUTE contracts. Fixtures use
TASK-006-specific UUIDs and `.invalid` emails. The exhaustive table/object
inventories include `notifications` (column-level `UPDATE(is_read)` for
authenticated — not table-wide UPDATE).

**Not duplicated here:** TASK-002 cost-price column details live in
`02_product_variant_cost_price.sql`; TASK-004 checkout totals/reservation/
concurrency live in `03_trusted_cod_checkout.sql` and
`03_trusted_cod_checkout_concurrency.sh`. Suite `05` remains the focused
Data API grant matrix from TASK-008. Suite `06` covers notifications
constraints and owner isolation (TASK-019).

### Explicit grants suite (TASK-008)

`05_explicit_data_api_grants.sql` asserts grant-layer privileges separately from
role-switched RLS behavior: anon catalog-only matrix, authenticated customer
CRUD + cross-user denial, staff/admin workflows under trusted `profiles.role`,
forged JWT role denial, `cost_price` column lockdown, and function EXECUTE
contracts. Notifications appear in the exhaustive object inventory with
authenticated table `SELECT`, no table-wide `UPDATE`/`INSERT`/`DELETE`, and
column-level `UPDATE` on `is_read` only.

### Notifications suite (TASK-019)

`06_notifications.sql` is a transaction-wrapped (`BEGIN`/`ROLLBACK`) regression
for `public.notifications`. It proves schema constraints (type allowlist,
non-blank title/body, object-only payload, null rejection, defaults), anon and
null-UID denial, customer A own select/mark-read, customer B isolation,
cross-owner update denial with no-mutation checks, authenticated denial of
content/owner updates plus INSERT/DELETE, and trusted `service_role`
insert/read/delete.

**Grants vs RLS for notifications:** column grants make content immutable to
customers (`is_read` is the only writable column); RLS `USING`/`WITH CHECK`
require a non-null `auth.uid()` matching `user_id`. See
`docs/backend/notifications_security.md`.

### CMS variant cost contract (TASK-026)

`07_cms_security_contract.sql` is a transaction-wrapped (`BEGIN`/`ROLLBACK`)
regression for `public.get_staff_variant_costs(p_product_id uuid)`.

Contract summary:

- **Caller:** PostgreSQL role `authenticated` only (EXECUTE revoked from
  `PUBLIC`, `anon`, and `service_role`). Customers still share
  `authenticated`, so EXECUTE alone is not authority.
- **Authorization:** every call requires non-null `auth.uid()` mapped to an
  active trusted `public.profiles` row with `role IN ('staff', 'admin')`.
  Missing, inactive, customer, unsupported-role, and forged JWT metadata
  cases receive the same generic authorization failure.
- **Output:** only `variant_id` and nullable `cost_price numeric(14,2)` for
  variants of the requested product, ordered by `sort_order, id`. No full
  variant rows, product fields, or public catalog projection of cost.
- **Column boundary unchanged:** `anon` / `authenticated` still lack
  table-wide SELECT and `SELECT(cost_price)` on `public.product_variants`.
  Trusted backend/`service_role` direct table access is unchanged and does
  not use this RPC.

The suite also re-checks representative staff/admin catalog and catalog-bucket
Storage write capabilities and customer denial of those mutations.

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

## Local verification checklist

Flutter commerce repositories (catalog, product, search, favorites, cart,
checkout, orders, addresses, home, auth/profile) are already wired to Supabase
in the app. This folder owns the database source of truth and local regressions.

1. Install Docker + CLI 2.111+
2. `supabase db reset` (local disposable stack only)
3. Run the local database regressions above
4. Verify `product_catalog` view returns active products

Do not treat “wire Flutter repositories” as remaining Supabase work. Remote
migration apply remains post-approval/merge via the established workflow — these
commands are for local verification only.
