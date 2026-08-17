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
verified recovery session. GoTrue records PKCE recovery as JWT `amr` method
`recovery` (`{ method, timestamp }`). After a successful password change the
recovery session must be signed out; sign-out errors are treated as failure and
do not report success. Recovery sessions cannot open `/dashboard`, including
for active staff or admin profiles, until the user signs in with the new
password.

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
- overview cards that link to catalog areas;
- shared loading, empty, error/retry, and confirmation primitives.

### Category management

`/dashboard/categories` lists categories with deterministic ordering, clamped
pagination, status, parent name, sort order, and image preview. Staff can create
and edit categories at `/dashboard/categories/new` and
`/dashboard/categories/[categoryId]/edit`.

Server Actions re-authorize active staff/admin before every mutation, validate
hierarchy (no self/descendant parents), sanitize slug conflicts and provider
failures, and upload optional images to the public `category-assets` bucket with
compensation for partial failures. Reads and writes use the cookie-backed SSR
client only; there is no client-side Supabase access for categories.

### Brand management

`/dashboard/brands` lists brands with deterministic ordering, clamped pagination,
status, country, website, sort order, and logo preview. Staff can create and
edit brands at `/dashboard/brands/new` and `/dashboard/brands/[brandId]/edit`.

Server Actions re-authorize active staff/admin before every mutation, validate
name, slug, optional HTTPS website URL, country, sort order, and activation,
sanitize slug conflicts and provider failures, and upload optional logos to the
public `brand-assets` bucket with compensation for partial failures. Logos are
rendered through the public object URL and never inlined as SVG. Reads and
writes use the cookie-backed SSR client only; there is no client-side Supabase
access for brands.

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
