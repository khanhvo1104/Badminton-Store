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

- Supabase CLI (`supabase --version`)
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

## Local database regressions

Obtain `DATABASE_URL` from `supabase status` (local DB URL). Run after
`supabase db reset` against the disposable local stack only. If host `psql`
is unavailable, pipe each file into the local DB container:

`docker exec -i supabase_db_Badminton-Store psql -U postgres -d postgres -v ON_ERROR_STOP=1 < path/to/file.sql`

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/00_constraints.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/02_product_variant_cost_price.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/03_trusted_cod_checkout.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/04_trigger_function_execute.sql
bash supabase/tests/database/03_trusted_cod_checkout_concurrency.sh
```

`01_rls_checklist.sql` remains a comment checklist, not an executable suite.

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

1. Install Docker + CLI
2. `supabase db reset`
3. Run the local database regressions above
4. Verify `product_catalog` view returns active products
