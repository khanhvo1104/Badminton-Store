# Badminton Store CMS

Production-oriented Next.js App Router scaffold for the Badminton Store
administration product.

## Setup

1. Install dependencies with `npm ci`.
2. Copy `.env.example` to a local `.env` file.
3. Set safe public placeholders or real local values for:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
   - `CMS_SITE_URL` (local development may use `http://localhost:3000`;
     production must be the HTTPS CMS origin, for example
     `https://cms.example.com`)

## Commands

```bash
npm run dev
npm run format
npm run format:check
npm run lint
npm run typecheck
npm test -- --run
npm run build
```

## Authentication flow

- `src/lib/supabase/browser.ts` creates the browser client for client-side auth
  UI only.
- `src/lib/supabase/server.ts` creates request-scoped server clients backed by
  Next.js `cookies()` for Server Components and Server Actions.
- `src/proxy.ts` is the optimistic session refresh boundary. It calls
  `supabase.auth.getClaims()`, forwards refreshed cookies to the upstream
  request, mirrors them to the browser response, and applies the SSR package's
  no-cache headers.

The CMS authorizes from the trusted `public.profiles` row only. Every protected
request validates claims server-side, selects only `id, full_name, role,
is_active` for the signed-in subject, and allows only active `staff` or active
`admin` profiles into the dashboard.

## Password recovery

Staff can request a reset from `/login` → `/forgot-password`. The server calls
`resetPasswordForEmail` with an explicit callback derived from `CMS_SITE_URL`:

- Production: `https://cms.example.com/auth/callback?next=/update-password`
- Local development/test only: `http://localhost:3000/auth/callback?next=/update-password`

Add this exact redirect URL to the Supabase Auth allow-list:

```text
https://cms.example.com/auth/callback
```

Replace `https://cms.example.com` with the production CMS origin stored in
`CMS_SITE_URL`. Do not add wildcards, `localhost` production fallbacks, or
implicit-grant token URLs.

The callback exchanges only a PKCE `code`, then `/update-password` requires a
verified recovery session. After a successful password change the recovery
session is signed out and the user returns to `/login`. Recovery alone does not
grant `/dashboard` access.

## Access prerequisites

- Self-signup is not part of the CMS.
- A project owner must create or promote the first active `admin` manually in
  Supabase before anyone can access the dashboard.
- Customer accounts, inactive profiles, missing profiles, and unsupported roles
  all receive the same sanitized unauthorized experience.

## Dashboard shell

Protected routes under `/dashboard` share one authorized layout shell with:

- desktop sidebar and mobile open/close navigation;
- skip link, breadcrumbs, and `aria-current` page treatment from typed routes;
- safe account display plus POST logout with pending state;
- overview cards that link only to placeholder catalog areas;
- shared loading, empty, error/retry, and confirmation primitives.

Add new dashboard areas by extending
`src/lib/navigation/dashboard-routes.ts` and placing pages under
`src/app/dashboard/`. Do not trust client state or URL text for roles or
breadcrumb labels.

## Notes

- The CMS uses only `NEXT_PUBLIC_SUPABASE_URL` and
  `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` in browser code, plus server-only
  `CMS_SITE_URL` for password-recovery callbacks.
- No service-role or secret key is created, stored, or exposed in browser code.
- Authenticated requests continue to use the signed-in user's JWT and remain
  subject to existing RLS and grants.
