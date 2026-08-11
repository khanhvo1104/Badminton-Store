# TASK-024 — Scaffold the Next.js CMS

Risk: medium

## Objective

- Create a production-oriented, independently runnable Next.js TypeScript CMS
  foundation under `cms/` that follows the accepted CMS architecture and is
  ready for Supabase authentication in TASK-025.

## Scope

- Scaffold a Next.js App Router application in `cms/` with TypeScript, Tailwind
  CSS, ESLint, npm, a committed lockfile, and pinned resolved dependencies.
- Establish the documented feature-first source boundaries and import alias.
- Add a minimal accessible CMS landing shell that clearly identifies the
  Badminton Store administration product and that authentication/catalog
  features are not yet connected.
- Add validated public environment configuration for the Supabase URL and
  publishable key without creating a Supabase client or live network call.
- Add unit/component test infrastructure and tests for configuration success,
  sanitized configuration failure, and the landing shell.
- Extend CI with an independent CMS job and document local CMS commands.

## Non-goals

- Do not implement login, logout, cookies, proxy/middleware, staff/admin route
  guards, database queries, Storage operations, catalog CRUD, Server Actions,
  Route Handlers, migrations, RLS, grants, RPCs, or deployment.
- Do not add a service-role/secret key, database URL, real credentials, generated
  Supabase database types, shadcn/ui, state-management library, form library,
  analytics, monitoring, or unrelated dependencies.
- Do not move or refactor the Flutter application or change its CI behavior.
- Do not edit the CMS architecture decision or roadmap as an implementation
  shortcut.

## Allowed paths

- `cms/`
- `.github/workflows/ci.yml`
- `.gitignore`
- `README.md`
- `docs/cms/README.md`
- `.automation/backlog.json`

## Acceptance criteria

- `cms/` is a standalone Next.js App Router TypeScript application installable
  reproducibly with `npm ci`; exact resolved dependency versions are committed
  in `cms/package-lock.json`.
- The application uses a clear `src/app`, `src/features`, `src/components`, and
  `src/lib` boundary with an `@/*` alias and no Flutter-source dependency.
- The landing route has a descriptive page title, one `h1`, accessible landmark
  structure, responsive styling, and honest foundation-only copy.
- Environment parsing accepts only non-empty valid HTTP(S) Supabase URLs and a
  non-empty publishable key from `NEXT_PUBLIC_SUPABASE_URL` and
  `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`.
- Missing or invalid configuration fails through a sanitized, tested application
  error that never includes an environment value, key, token, stack trace, or
  backend detail in user-facing copy.
- No service-role key, secret key, database password, real project value, live
  Supabase client, network request, auth/session code, or catalog operation is
  present.
- `cms/.env.example` contains safe placeholders; local `.env*` files are ignored
  while the example remains tracked.
- Tests run without network access and cover valid configuration, each invalid
  configuration class, secret-safe failure output, and the landing shell's main
  content/accessibility contract.
- The root README and CMS README provide concise install, environment, dev,
  lint, typecheck, test, and build commands.
- GitHub CI contains a least-privilege CMS job using `npm ci` and runs formatting
  check if configured, lint, typecheck, tests, and production build with safe
  placeholder public environment values.
- Existing Flutter CI remains operational and independent from the CMS job.

## Required quality gates

- `cd cms && npm ci`
- `cd cms && npm run format:check`
- `cd cms && npm run lint`
- `cd cms && npm run typecheck`
- `cd cms && npm test -- --run`
- `cd cms && npm run build`
- `git diff --check`
- `python3 scripts/automation.py policy-check`
