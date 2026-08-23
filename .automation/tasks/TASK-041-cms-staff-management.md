# TASK-041 — Build CMS staff management

Risk: high

Status: complete

## Objective

- Add admin-only staff invitation, activation, and role management with
  server-side pagination/search, trusted profile authorization, and audit
  support.
- Route Auth Admin `inviteUserByEmail` through a Supabase Edge Function that
  validates the caller access token and re-checks active admin from
  `public.profiles` before using the runtime service-role key.
- Prevent self-deactivation/self-demotion and last-active-admin removal under
  concurrency. Never authorize from user-editable metadata.

## Scope

- One CLI-created migration:
  `staff_management_events`, `list_cms_staff`, `update_cms_staff`, admin-only
  profile update policy, and a trusted mutation boundary trigger for
  `role` / `is_active`.
- Edge Function `invite-cms-staff` with user JWT validation, admin re-check,
  sanitized SMTP rate-limit errors, and profile role assignment after invite.
- Admin-only `/dashboard/staff` with Server Component reads and Server Actions
  for activation/role changes plus invite via the Edge Function boundary.
- Focused CMS, Edge Function, and DB regression tests including negative
  authorization, concurrency/last-admin, function EXECUTE, invitation
  boundary, and PII minimization.

## Non-goals

- Flutter files or Flutter CI/analyze/test/build.
- SMTP configuration, self-signup, customer role editing, or audit trail UI.
- Service-role/secret keys in the CMS browser bundle or committed env files.
- Real invitation emails during automated tests.
- Remote migration application or deployment.

## Allowed paths

- `cms/src/app/dashboard/staff/**`
- `cms/src/features/staff/**`
- `cms/src/lib/auth/**`
- `cms/src/lib/navigation/dashboard-routes.ts`
- `cms/src/lib/navigation/dashboard-routes.test.ts`
- `cms/src/components/layout/dashboard-shell.tsx`
- `cms/src/components/layout/dashboard-navigation.tsx`
- `cms/src/app/dashboard/layout.tsx`
- `cms/README.md`
- `docs/cms/**`
- `docs/backend/database_schema.md`
- `docs/backend/rls_policies.md`
- `supabase/migrations/**`
- `supabase/functions/invite-cms-staff/**`
- `supabase/config.toml`
- `supabase/tests/database/**`
- `supabase/README.md`
- `.automation/backlog.json`
- `.automation/tasks/TASK-041-cms-staff-management.md`

## Required quality gates

- Discover Supabase CLI commands via `--help`
- `supabase db reset` (local disposable only)
- `supabase migration list --local`
- `supabase db lint` when supported
- Relevant `01`, `05`, and `13_cms_staff_management.sql` (+ concurrency script)
- Edge Function unit tests when supported
- `cd cms && npm run format:check`
- `cd cms && npm run lint`
- `cd cms && npm run typecheck`
- `cd cms && npm test -- --run`
- `cd cms && npm run build`
- Do not run Flutter commands
- `git diff --check`
- `python3 scripts/automation.py policy-check`
