# CMS deployment and operations runbook

Operational guide for staging/production CMS releases, monitoring, backups, and
incidents. This document does **not** claim that dashboard settings are already
enabled. Items marked **HUMAN** require an operator in Vercel/Supabase/GitHub.

Official references (verify in product docs before changing entitlements):

- Vercel Git / production branch: https://vercel.com/docs/git
- Vercel Deployment Checks: https://vercel.com/docs/deployment-checks
- Vercel Instant Rollback: https://vercel.com/docs/instant-rollback
- Vercel environment variables: https://vercel.com/docs/environment-variables
- Supabase backups / PITR: https://supabase.com/docs/guides/platform/backups
- Supabase Auth rate limits / SMTP: https://supabase.com/docs/guides/auth/rate-limits

## 1. Environment separation and ownership

| Environment       | CMS app                            | Supabase project                  | Owner                     |
| ----------------- | ---------------------------------- | --------------------------------- | ------------------------- |
| Local             | `cms/` + disposable CLI stack      | Local Docker via `supabase start` | Developers                |
| Staging / preview | Vercel Preview (or staging domain) | Non-production Supabase project   | CMS maintainers           |
| Production        | Vercel Production domain           | Production Supabase project       | CMS maintainers + on-call |

Rules:

- Never point a production CMS deployment at a non-production Supabase project
  (or the reverse).
- Flutter storefront and CMS release independently; database migrations remain
  the shared source of truth under `supabase/migrations/`.
- Repository secrets must not include service-role keys in the CMS client
  bundle. Only `NEXT_PUBLIC_SUPABASE_URL`,
  `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, and server-only `CMS_SITE_URL` belong
  in the CMS runtime contract (see `cms/.env.example`).

## 2. Vercel Git production branch and Deployment Checks (**HUMAN**)

Confirm in the Vercel project (not assumed enabled by this repository):

1. **Production Branch** tracks the Git branch that should create Production
   deployments (this monorepo uses `develop` as the integration branch; set the
   Vercel Production Branch to match the branch you intentionally promote).
2. Root Directory / install command target `cms/` if the Vercel project is CMS
   only.
3. **Deployment Checks** (optional protection): configure required GitHub checks
   so Production domains are not assigned until checks pass. See Vercel
   Deployment Checks docs. Enabling this is a dashboard action.
4. Environment variables for Production vs Preview are set separately in the
   Vercel project settings. Changing env vars does **not** mutate prior
   deployments; new values apply on the next build/deploy.

## 3. Preview / staging validation and approval evidence

Before promoting traffic:

1. Open the Vercel Preview deployment for the release commit.
2. Run the operator smoke check (HTTPS):

   ```bash
   cd cms
   node scripts/smoke-check.mjs --base-url https://YOUR_PREVIEW_HOST
   ```

3. Manually exercise login, one catalog read, and one harmless staff read path
   on staging data only.
4. Record approval evidence in the release PR or change ticket: commit SHA,
   preview URL, smoke-check exit code `0`, and reviewer name/time.
5. Do not paste cookies, JWTs, service-role keys, or customer PII into tickets.

## 4. Production release and post-deploy smoke checks

1. Merge to the branch that drives Production (after review). Codex merges task
   PRs into `develop`; production promotion policy is a human release decision.
2. Wait for Vercel Production deployment success (and Deployment Checks, if
   enabled).
3. Immediately run:

   ```bash
   cd cms
   node scripts/smoke-check.mjs --base-url https://YOUR_PRODUCTION_HOST
   ```

4. Confirm `/api/health` returns HTTP 200 with `{"status":"ok","check":"liveness"}`.
5. Confirm `/api/ready` returns HTTP 200 with readiness `dependencyStatus:"ok"`.
   A `503` means the process is up but Supabase dependency checks failed—treat
   as failed deploy for traffic purposes.
6. Spot-check staff login on production without exporting session material.

Local escape hatch only:

```bash
node scripts/smoke-check.mjs --base-url http://127.0.0.1:3000 --allow-localhost
```

## 5. Rollback criteria and Instant Rollback limits

**Rollback when any of the following is true after a production deploy:**

- Smoke check fails (liveness or readiness).
- Elevated 5xx / function errors beyond agreed thresholds (see monitoring).
- Auth lockout or blank env preventing staff login.
- Data-corrupting CMS writes (stop traffic first; DB restore is a separate decision).

**Instant Rollback (Vercel dashboard/CLI — HUMAN):**

- Instant Rollback re-points production domains to a prior eligible production
  deployment without rebuilding.
- Environment variables are **not** rebuilt: the rolled-back deployment keeps
  the env baked into that prior build. If the incident is a bad env change, an
  Instant Rollback alone may be insufficient—fix env and redeploy/promote a
  good build.
- After Instant Rollback, Vercel turns off auto-assignment of production
  domains until rollback is undone / another deployment is promoted. Confirm
  this in the dashboard after rolling back.
- Eligibility and how far back you can roll depend on the Vercel plan; do not
  invent entitlements—check current Instant Rollback docs for your plan.

## 6. Supabase migrations sequencing and compatibility

1. Never edit a migration that has already been applied to staging/production.
2. Ship additive, backward-compatible migrations first when CMS and Flutter are
   on different release clocks.
3. Apply migrations to the matching non-production Supabase project, verify CMS
   preview + DB tests, then apply to production during a controlled window.
4. Prefer expand/contract for breaking column/RPC changes.
5. CMS code that requires a new RPC must not deploy to production before that
   migration is applied (readiness may still pass; feature paths will fail).

## 7. Backup tier, PITR verification, RPO/RTO recording (**HUMAN**)

Hosted backup capabilities vary by Supabase plan (daily backups vs PITR). This
repo does **not** enable or verify hosted backups automatically.

Operator checklist (record in the ops log / ticket):

| Field                         | What to record                                             |
| ----------------------------- | ---------------------------------------------------------- |
| Backup tier                   | Plan feature actually enabled (dashboard evidence)         |
| PITR window                   | Retention hours/days shown in project settings             |
| Last backup verification date | Timestamp of successful check                              |
| RPO target / actual           | e.g. target 24h; actual based on last good backup          |
| RTO target / actual           | Time to restore into a **separate non-production** project |

Automated **local** rehearsal (no hosted project, no artifacts committed):

```bash
supabase start
supabase db reset --yes
bash scripts/cms-backup-rehearsal.sh
supabase stop --no-backup
```

This proves logical `supabase db dump --local` → isolated restore of
representative `public` schema/data. The rehearsal never runs
`supabase status` (env/JSON/table) or otherwise reads service-role/secret
keys; it fail-closes on unique local `supabase_db_*` container checks plus
`--local` dumps only. It does **not** replace hosted PITR/physical backup
drills.

## 8. Quarterly restore drill (**HUMAN**)

At least once per quarter:

1. Create or select a **separate non-production** Supabase project.
2. Restore from the production backup/PITR method available on your plan into
   that project only (never overwrite production to “test” restore).
3. Point a disposable CMS preview env at the restored project and run smoke +
   a staff read path.
4. Record RPO/RTO actuals, gaps (Storage objects, Auth mail, extensions), and
   destroy or isolate the drill project when finished.
5. Do not upload backup dumps into this Git repository.

## 9. Monitoring signals and thresholds

| Signal         | Source                | Suggested threshold                      | Action                               |
| -------------- | --------------------- | ---------------------------------------- | ------------------------------------ |
| Liveness fail  | `GET /api/health`     | Any non-200 from probe                   | Page on-call; check Vercel runtime   |
| Readiness fail | `GET /api/ready`      | Non-200 for >2 min                       | Check Supabase status + CMS env      |
| HTTP 5xx rate  | Vercel analytics/logs | Agree team baseline (start: >2% / 5 min) | Rollback candidate                   |
| Auth errors    | Supabase Auth logs    | Spike vs baseline                        | Check SMTP/custom SMTP + rate limits |
| Build fail     | Vercel build          | Any production build failure             | Block release                        |

Wire external uptime checks to `/api/health` (process) and `/api/ready`
(dependency). Both endpoints are `no-store`, JSON-only, and omit secrets,
SQL, stack traces, and env values.

Structured logs for these routes use allowlisted fields only (`event`,
`requestId`, `route`, `method`, `status`, `durationMs`, `outcome`,
`errorCode`). Request bodies, cookies, and `Authorization` headers are never
logged.

## 10. Runtime / build log triage

1. Prefer Vercel deployment “Build” logs for compile/env miss failures.
2. Prefer Vercel “Runtime” logs for 5xx after a successful deploy.
3. Prefer Supabase API/Auth logs for dependency readiness failures.
4. Redact: JWTs, `service_role`, connection strings, emails, phones, addresses,
   raw SQL errors, and `.env` values before sharing logs.
5. Correlation: pass/propagate `x-request-id` when probing; CMS readiness logs
   will echo a safe correlation id when present.

## 11. Auth / SMTP quota and custom SMTP prerequisite (**HUMAN**)

- Hosted Supabase Auth email is rate-limited; production staff invite/password
  recovery should use **custom SMTP** configured in the Supabase project
  (dashboard). Do not assume custom SMTP is already enabled.
- Confirm redirect allow-list includes `{CMS_SITE_URL}/auth/callback` for each
  environment.
- Staging and production must not share OTP/SMTP quotas if invite volume is
  high—prefer separate projects.
- The CMS Playwright suite uses local Auth only and must not consume hosted
  SMTP quota.

## 12. Severity, roles, communications, evidence, decision tree

### Severity

| Level | Example                                    | Response                                               |
| ----- | ------------------------------------------ | ------------------------------------------------------ |
| SEV-1 | Production CMS down / data corruption risk | Immediate rollback/restore decision; all-hands on-call |
| SEV-2 | Readiness failing / staff cannot login     | Rollback or env fix within business hours SLA          |
| SEV-3 | Non-blocking UI defect                     | Ticket; next release                                   |
| SEV-4 | Docs/tooling                               | Backlog                                                |

### Roles

- **Incident lead:** coordinates decisions and customer/staff comms.
- **CMS engineer:** Vercel deploy/rollback + app logs.
- **Data engineer/DBA:** Supabase migrations/backups/restore.
- **Comms owner:** status updates to stakeholders (no PII/secrets).

### Communications

- Acknowledge SEV-1/2 within 15 minutes on the team channel.
- Hourly updates until mitigated.
- Never paste secrets, customer PII, or full backup outputs into chat.

### Evidence preservation

- Capture deployment URL/SHA, smoke-check output (sanitized), approximate
  error rates, and timeline.
- Do not download production data dumps into laptops without approval and
  encryption controls.

### Decision tree (rollback vs restore)

```text
Smoke/liveness fail?
  yes -> Instant Rollback (app). Re-run smoke.
Readiness fail only?
  yes -> Check Supabase status + CMS env; fix env and redeploy if needed.
         Instant Rollback if bad app build; env-only incidents need redeploy.
Corrupt writes / lost rows?
  yes -> Stop writes; DBA-led restore into non-prod validation first;
         production restore only with explicit approval.
Auth/SMTP incident?
  yes -> Disable invite storms; verify custom SMTP; do not widen RLS.
```

### Post-incident follow-up

Within 5 business days: root cause, timeline, customer/staff impact, detection
gaps, checklist updates to this runbook, and any new automated guard (test,
smoke assertion, or CI rehearsal).

## 13. CI automation shipped with TASK-044

- Unit/contract tests for `/api/health`, `/api/ready`, operational logging, and
  `cms/scripts/smoke-check.mjs`.
- CI job steps run CMS tests/build and, with the local Supabase stack, the
  backup rehearsal script plus the smoke CLI against localhost.
- No repository secrets are required for these checks.
- No backup artifacts are uploaded or committed.
