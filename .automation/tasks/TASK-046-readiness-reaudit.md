# TASK-046 — Re-audit application readiness after CMS completion

Risk: low

Status: complete

## Objective

- Replace the stale 2026-08-11 readiness audit with an evidence-backed
  2026-08-26 baseline after Flutter notifications/home work and the full CMS
  roadmap (through TASK-044) plus facade cleanup (TASK-045).
- Queue only concrete, non-overlapping next code tasks when evidence warrants;
  keep human/dashboard ops out of executable automation tasks.

## Scope

- Inspect Flutter, CMS, migrations/tests, CI, docs, automation backlog, stubs,
  routes, security boundaries, and coverage via repository evidence.
- Update `docs/audits/application-readiness.md` and directly related stale
  status docs only as needed.
- Add this task file; mark TASK-046 complete; add TASK-047+ when justified.
- Documentation / `.automation` metadata only.

## Non-goals

- No Dart/TypeScript/application behavior, migrations, workflows, dependencies,
  lockfiles, hosted services, env files, secrets, or remote Supabase commands.
- Do not invent hosted SMTP, Vercel Deployment Checks, monitoring, PITR, or
  remote migration state.
- Do not run Flutter/CMS/Supabase suites for this docs-only change.

## Allowed paths

- `docs/audits/application-readiness.md`
- `docs/architecture.md`
- `docs/coding_guidelines.md`
- `docs/feature_workflow.md`
- `docs/cms/README.md`
- `docs/backend/notifications_security.md`
- `README.md`
- `.automation/backlog.json`
- `.automation/tasks/TASK-046-readiness-reaudit.md`
- `.automation/tasks/TASK-047-*.md`
- `.automation/tasks/TASK-048-*.md`

## Acceptance criteria

- Readiness audit dated 2026-08-26 with current verdict, matrix, old-P2
  disposition, classified gaps, security boundaries, honest CI reliance, and
  human ops checklist.
- TASK-046 complete in backlog; follow-up tasks (if any) are ready, scoped,
  non-overlapping, with quality gates.
- Diff is documentation/automation-only; policy-check and `git diff --check`
  pass; no secrets.

## Required quality gates

- Repository-wide `rg` evidence for stubs/TODOs/UnimplementedError
- `python3 -c` JSON validate on `.automation/backlog.json`
- `python3 scripts/automation.py policy-check`
- `git diff --check`
- Do **not** run Flutter/CMS/Supabase suites

## Result

Completed on branch `automation/task-046-readiness-reaudit`. Queued TASK-047
(notification producers) and TASK-048 (order_update → `/orders` navigation).
