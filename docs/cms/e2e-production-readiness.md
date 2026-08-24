# CMS production-readiness E2E suite

Playwright browser tests for critical CMS auth, authorization, catalog
mutation, inventory/order read boundaries, accessibility, session fail-closed
behavior, and sanitized mutation failure recovery.

This suite targets the **disposable local Supabase stack** and a **local Next.js
CMS** only. It does **not** use hosted Supabase, hosted SMTP, production data,
or repository secrets.

## Prerequisites

- Docker running
- Supabase CLI available on `PATH` (local verification used `2.111.0`)
- Node.js 22.x
- From `cms/`: `npm ci`
- Chromium for Playwright: `npm run test:e2e:install`

## Expected local ports

| Service | Port |
| --- | --- |
| CMS (Next.js) | `127.0.0.1:3000` |
| Supabase API | `127.0.0.1:54321` |
| Postgres | `127.0.0.1:54322` |
| Studio | `127.0.0.1:54323` |
| Mailpit (local email catcher only) | `127.0.0.1:54324` |

Mailpit may be present with local Supabase, but this suite does not send real
email and does not consume hosted SMTP quota.

## Exact commands

From the repository root:

```bash
supabase start
supabase db reset --yes
```

From `cms/`:

```bash
npm ci
npm run test:e2e:install
npm run format:check
npm run lint
npm run typecheck
npm test -- --run
npm run test:e2e
```

`npm run test:e2e` writes a gitignored `.env.e2e.local` from `supabase status`,
builds the CMS, starts `next start` on `127.0.0.1:3000`, seeds disposable
fixtures, and runs Playwright.

To run Playwright alone after an existing production build and env prepare:

```bash
npm run test:e2e:env
cp .env.e2e.local .env.local   # optional; Next loads .env.local
npm run build
npx playwright test
```

## Teardown

```bash
# from repo root
supabase stop --no-backup
```

Playwright global teardown also removes disposable E2E auth users, the seeded
order, and `cms-e2e-*` categories. Generated reports live under
`cms/playwright-report/` and `cms/test-results/` (gitignored). Traces, videos,
and screenshots are retained on failure only.

## What the suite covers

- Unauthenticated `/dashboard*` redirect to `/login`
- Customer login fail-closed to `/unauthorized`
- Staff dashboard access without admin-only nav/surfaces
- Admin-only staff surface access
- Category create validation + successful mutation
- Keyboard/focus behavior for the category activation confirmation dialog
- Inventory read without cost-price leakage
- Seeded order detail + status transition confirmation dialog
- Session cookie clear / corrupt fail-closed behavior
- Mutation network failure with sanitized UI and successful retry
- axe serious/critical checks on login, dashboard, list/form/modal pages
- Mobile viewport smoke

## Troubleshooting

- **`Local Supabase is not available`**: run `supabase start` from the repo
  root and confirm `supabase status` succeeds.
- **Auth/login failures**: run `supabase db reset --yes`, then re-run
  `npm run test:e2e` so fixtures are recreated against a clean local DB.
- **Port 3000 busy**: stop other Next.js processes; the suite binds
  `127.0.0.1:3000`.
- **Docker container name mismatch**: set `CMS_E2E_DB_CONTAINER` if your local
  DB container is not `supabase_db_Badminton-Store`.
- **Never commit** `.env`, `.env.local`, `.env.e2e.local`, Playwright artifacts,
  credentials, or service-role keys.
