# TASK-001 — Audit current application readiness

Risk: low

## Objective

Audit the current Badminton Store application and produce a repository-tracked readiness report. Do not implement product features in this task.

## Scope

- Inspect Flutter features, providers, repositories, routes, tests, and documentation.
- Inspect Supabase migrations, RLS tests, storage policies, and Flutter integration notes.
- Identify placeholders, `UnimplementedError` sites, missing wiring, security risks, and missing tests.
- Write the result to `docs/audits/application-readiness.md`.

## Acceptance criteria

- The report groups findings into P0, P1, and P2.
- Every finding cites concrete repository paths.
- The report proposes small, ordered implementation tasks.
- No application code, database migration, environment file, or dependency is changed.
- Existing checks still pass.

## Allowed paths

- `docs/audits/application-readiness.md`

## Forbidden actions

- Do not change application behavior.
- Do not modify Git state.
- Do not access remote Supabase data.

