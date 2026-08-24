# TASK-043 — CMS production-readiness Playwright suite

Risk: high

Status: complete

## Objective

- Deliver roadmap Milestone 4 **TASK-039** (end-to-end, accessibility, security,
  and failure recovery suite) as automation **TASK-043**.
- Add focused Playwright coverage for CMS auth/authorization boundaries, catalog
  mutation + failure recovery, inventory/order read boundaries, session
  fail-closed behavior, axe accessibility, keyboard/modal focus, and mobile
  smoke against disposable local Supabase only.

## Scope

- Playwright E2E specs, fixtures, helpers, and local start/env scripts under
  `cms/e2e/` and `cms/scripts/`.
- Wire a `cms-e2e` GitHub Actions job using Docker/local Supabase with no
  repository secrets; Playwright artifacts remain gitignored.
- Document exact local commands/ports/teardown.
- Small CMS fixes required for reliable E2E (dynamic `/unauthorized`, empty
  image upload handling, dashboard definition-list a11y).

## Non-goals

- Flutter files, Flutter CI, hosted Supabase, hosted SMTP, production data, or
  repository secrets.
- Remote migration application or deployment.

## Allowed paths

- `cms/e2e/**`
- `cms/scripts/e2e-local-env.mjs`
- `cms/scripts/e2e-start.mjs`
- `cms/playwright.config.mjs`
- `cms/package.json`
- `cms/package-lock.json`
- `cms/tsconfig.json`
- `cms/eslint.config.mjs`
- `cms/.gitignore`
- `cms/.prettierignore`
- `cms/README.md`
- `cms/src/app/globals.css`
- `cms/src/app/unauthorized/page.tsx`
- `cms/src/features/categories/image.ts`
- `cms/src/features/operational-dashboard/components/operational-dashboard.tsx`
- `docs/cms/**`
- `.github/workflows/ci.yml`
- `.gitignore`
- `.automation/backlog.json`
- `.automation/tasks/TASK-043-cms-production-readiness-suite.md`

## Result

Merged as PR #75 (`automation/task-043-cms-production-readiness-suite`) into
`develop`. Durable queue record restored by TASK-045 without rewriting the
implementation history.
