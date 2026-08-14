# Badminton Store CMS

This directory defines the target architecture and delivery roadmap for the
staff-facing product management system. The CMS is a separate deployable
Next.js application that lives in `cms/` and shares the existing Supabase
project with the Flutter storefront.

## Documents

- [System architecture](system-architecture.md)
- [Security and authorization](security.md)
- [Delivery roadmap](roadmap.md)
- [ADR-006: Next.js for the CMS](../architecture/006-nextjs-cms.md)

## Product boundary

The first milestone is a product-management MVP: authenticated staff can manage
categories, brands, products, variants, inventory, and catalog images. Order
operations, staff administration, analytics, and audit reporting follow after
the catalog workflow is stable.

The Flutter app remains the customer storefront. The CMS must not import Flutter
code or introduce a second source of truth for database types or authorization.
Supabase migrations remain the database source of truth.

## Local application

The runnable CMS application lives in `cms/` and is installed independently
from the Flutter storefront.

### Setup

```bash
cd cms && npm ci
cp .env.example .env.local
```

Required public placeholders or local values:

```bash
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
CMS_SITE_URL=http://localhost:3000
```

### Commands

```bash
cd cms && npm run dev
cd cms && npm run format:check
cd cms && npm run lint
cd cms && npm run typecheck
cd cms && npm test -- --run
cd cms && npm run build
```

The CMS now uses Supabase SSR authentication with three separate concerns:

- browser auth UI via `cms/src/lib/supabase/browser.ts`
- request-scoped server auth/data access via `cms/src/lib/supabase/server.ts`
- optimistic session refresh in `cms/src/proxy.ts`

Proxy refreshes cookies with `supabase.auth.getClaims()` and forwards refreshed
cookies to both the upstream request and browser response. Proxy is not an
authorization boundary: protected pages, Server Actions, and Route Handlers must
still validate identity and authorization independently.

CMS authorization trusts only the signed-in user's `public.profiles` row,
restricted to `id, full_name, role, is_active`. Active `staff` and active
`admin` profiles are allowed; anonymous users go to `/login`; all other
authenticated cases receive the same sanitized `/unauthorized` response.

There is no self-signup or staff-management flow in this milestone. A trusted
operator must manually create or promote the first active admin before the CMS
can be used.

## Password recovery

The CMS login page includes a “Forgot password?” flow. Recovery emails use a
callback derived from server-only `CMS_SITE_URL` and never fall back to
`localhost` in production.

Production origin (example):

```text
CMS_SITE_URL=https://cms.example.com
```

Required Supabase Auth redirect allow-list entry:

```text
https://cms.example.com/auth/callback
```

Use the deployed CMS origin in place of `https://cms.example.com`. Local
development may set `CMS_SITE_URL=http://localhost:3000` and allow-list
`http://localhost:3000/auth/callback`. After the user chooses a new password,
the recovery session is cleared and `/dashboard` still requires an active
staff or admin profile.

## Dashboard shell

Authenticated staff land in `/dashboard`, which is wrapped by a protected App
Router layout. The shell provides:

- desktop sidebar and labelled mobile navigation;
- skip link to a single `main` landmark;
- breadcrumbs and current-page treatment from a typed route map;
- safe display-name and trusted role context with POST logout;
- reusable loading, empty, sanitized error/retry, and confirmation primitives.

Placeholder routes under `/dashboard/categories`, `/dashboard/brands`,
`/dashboard/products`, and `/dashboard/inventory` keep primary navigation
functional before their CRUD tasks. Navigation labels never come from raw URL
segments or query parameters. Layout and navigation are not a substitute for
authorization inside future Server Actions or Route Handlers.

Extension points for later catalog tasks:

- add a typed entry to `cms/src/lib/navigation/dashboard-routes.ts`;
- place feature UI under `cms/src/features/<area>/` and a matching App Router
  page under `cms/src/app/dashboard/<area>/`;
- reuse `LoadingState`, `EmptyState`, `ErrorState`, and `ConfirmationDialog`
  instead of inventing page-local status patterns.
