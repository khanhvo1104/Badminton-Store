# TASK-019 — Build least-privilege notifications backend

Risk: high

## Objective

- Add the minimal database source of truth for private in-app notifications, with explicit Data API grants, owner-isolating RLS, efficient unread/history indexes, and executable security regressions.

## Scope

- Use `supabase migration new notifications_backend` to create one new migration; never edit a deployed migration.
- Add `public.notifications` for immutable notification content plus a customer-controlled read flag.
- Add explicit grants and RLS for authenticated owner reads/read-state updates and trusted backend writes.
- Extend existing exhaustive RLS/grant inventories and add a focused Notifications database regression.
- Document the backend contract for the later Flutter repository/UI task.

## Non-goals

- Do not implement or wire Flutter Notifications repository/UI/providers in this task.
- Do not add Realtime publication, push notifications, email/SMS delivery, Edge Functions, cron jobs, broadcast, device tokens, or notification preferences.
- Do not add authenticated customer INSERT/DELETE, staff UI, public/anon access, or a `SECURITY DEFINER` function.
- Do not derive authorization from JWT/user metadata; ownership is `auth.uid()` against the row.
- Do not apply migrations to remote Supabase in this implementation PR; verification is against the disposable local stack.
- Do not edit existing deployed migration files or unrelated schemas/tests/docs.

## Allowed paths

- `supabase/migrations/`
- `supabase/tests/database/01_rls_checklist.sql`
- `supabase/tests/database/05_explicit_data_api_grants.sql`
- `supabase/tests/database/06_notifications.sql`
- `supabase/README.md`
- `docs/backend/notifications_security.md`
- `.automation/backlog.json`

## Acceptance criteria

- A new CLI-generated migration creates `public.notifications` with UUID primary key/default, non-null owner FK to `public.profiles(id)` with intentional delete behavior, constrained type values matching Flutter (`order_update`, `promotion`, `system`, `stock_alert`), non-blank title/body, object-only JSONB payload defaulting to `{}`, boolean `is_read` default false, and timezone-aware `created_at` default.
- Schema uses appropriate Postgres types and named constraints; no float/money, secrets, token fields, user metadata, or privileged credentials are stored.
- Indexes support owner history pagination (`user_id`, newest `created_at`, stable ID tie-breaker) and efficient unread lookups/counts with a partial owner index; the owner FK is indexed.
- RLS is enabled. Authenticated SELECT is limited to `auth.uid() is not null` and the row owner. Authenticated UPDATE has both `USING` and `WITH CHECK` owner predicates.
- Grants are explicit and least privilege: `PUBLIC`/`anon` have no SIUD; `authenticated` has SELECT plus column-level UPDATE of `is_read` only, with no INSERT/DELETE or ability to update owner/content/payload/type/timestamps; `service_role` has trusted operational access.
- No client-callable function or broad `GRANT ALL` is introduced for `anon`/`authenticated`; no default privileges are broadened.
- Suite `01` and suite `05` include Notifications in their exhaustive object/grant/RLS inventories, including column-level UPDATE assertions rather than falsely requiring table-wide UPDATE.
- `06_notifications.sql` transactionally proves constraints, anon denial, unauthenticated denial, customer A own select/read update, customer B isolation, cross-user update denial/no mutation, customer content/owner update denial, customer insert/delete denial, and trusted service-role insert/read/delete behavior; fixtures roll back and no secret/JWT content is printed.
- Documentation states that server/service-role processes create immutable notification content, Flutter may only list/count/mark read for the signed-in owner, and the later client must use only publishable/legacy anon configuration.
- Migration and all database suites pass from a fresh local reset; no remote project is mutated.

## Required quality gates

- `supabase --version`
- `supabase db reset`
- Execute `supabase/tests/database/00_constraints.sql` using the established local `psql "$DATABASE_URL"` command or Docker fallback documented in `supabase/README.md`
- `bash supabase/tests/database/01_rls_checklist.sh`
- Execute `supabase/tests/database/02_product_variant_cost_price.sql`
- Execute `supabase/tests/database/03_trusted_cod_checkout.sql`
- `03_trusted_cod_checkout_concurrency.sh`
- Execute `supabase/tests/database/04_trigger_function_execute.sql`
- Execute `supabase/tests/database/05_explicit_data_api_grants.sql`
- Execute `supabase/tests/database/06_notifications.sql`
- `supabase db lint`
- `supabase migration list --local`
- `flutter analyze`
- `flutter test`
- `git diff --check`
- `python3 scripts/automation.py policy-check`
