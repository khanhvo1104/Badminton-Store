# TASK-044 — CMS deployment operations and production readiness

Risk: high

Status: complete

## Objective

- Deliver roadmap Milestone 4 **TASK-040** (staging/production deployment,
  monitoring, backup checks, and operational runbook) as automation **TASK-044**.
- Add sanitized CMS liveness/readiness contracts, operator smoke checks, and a
  local-only backup rehearsal without capturing secrets.

## Scope

- Sanitized CMS `/api/health` (liveness) and `/api/ready` (dependency readiness)
  with bounded timeouts, `no-store` JSON, and privacy-safe operational logging.
- HTTPS-first `cms/scripts/smoke-check.mjs` for operators/CI.
- Local-only `scripts/cms-backup-rehearsal.sh` that dumps/restores representative
  schema/data in an isolated disposable database.
- CI wiring for unit tests, localhost smoke, and backup rehearsal.
- Staging/production safeguards in `docs/cms/operations-runbook.md`.

## Non-goals

- Flutter files or Flutter CI.
- Hosted Supabase remote commands, production restore, or committing backup
  artifacts, `.env`, service-role keys, or tokens.

## Allowed paths

- `cms/src/app/api/health/**`
- `cms/src/app/api/ready/**`
- `cms/src/lib/ops/**`
- `cms/src/lib/supabase/proxy.test.ts`
- `cms/src/proxy.ts`
- `cms/scripts/smoke-check.mjs`
- `cms/scripts/lib/smoke-check.mjs`
- `cms/scripts/smoke-check.test.mjs`
- `cms/playwright.config.mjs`
- `cms/package.json`
- `cms/vitest.config.ts`
- `cms/README.md`
- `docs/cms/**`
- `scripts/cms-backup-rehearsal.sh`
- `.github/workflows/ci.yml`
- `.automation/backlog.json`
- `.automation/tasks/TASK-044-cms-deployment-operations.md`

## Result

Merged as PR #76 (`automation/task-044-cms-deployment-operations`) into
`develop`. Durable queue record restored by TASK-045 without rewriting the
implementation history.
