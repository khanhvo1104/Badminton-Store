# Badminton Store CMS

This directory defines the target architecture and delivery roadmap for the
staff-facing product management system. The CMS is a separate deployable
Next.js application that lives in `cms/` and shares the existing Supabase
project with the Flutter storefront.

## Documents

- [System architecture](system-architecture.md)
- [Security and authorization](security.md)
- [Delivery roadmap](roadmap.md)
- [Production-readiness E2E](e2e-production-readiness.md)
- [Deployment and operations runbook](operations-runbook.md)
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
the recovery session must be signed out (sign-out errors are failures) and
`/dashboard` still requires an active staff or admin profile signed in with a
password. A recovery session does not authorize the dashboard.

## Dashboard shell

Authenticated staff land in `/dashboard`, which is wrapped by a protected App
Router layout. The shell provides:

- desktop sidebar and labelled mobile navigation;
- skip link to a single `main` landmark;
- breadcrumbs and current-page treatment from a typed route map;
- safe display-name and trusted role context with POST logout;
- reusable loading, empty, sanitized error/retry, and confirmation primitives.

The overview at `/dashboard` loads operational metrics from
`get_cms_operational_dashboard` with a 7/30/90-day range selector (default 30).
Gross order value is grouped by `currency_code` without cross-currency summation;
daily series are zero-filled per currency in UTC.

`/dashboard/inventory` is a production inventory explorer with server-side
pagination, product/variant/SKU search, stock filters, and stable sorting.
Staff adjust a variant at `/dashboard/inventory/[variantId]` through
`adjust_cms_inventory`. Reserved quantity is read-only. `/dashboard/products` is a
read-only product explorer with linked create/edit/detail routes for core
product fields, a per-product variant editor at
`/dashboard/products/[productId]/variants`, and a product media manager at
`/dashboard/products/[productId]/media`. The explorer provides server-side pagination, escaped name/slug
search, category/brand/status/stock filters, selling-price range, variant
counts, and staff-safe inventory summaries without selecting `cost_price`. Stock
filtering and price sorting happen in `list_cms_products` before pagination.
Primary images render through the public `product-images` object URL and are
never inlined as SVG. Variant costs are loaded only on the variant editor
through `get_staff_variant_costs` and merged by variant id. Product images are
managed at `/dashboard/products/[productId]/media` with Storage/database
compensation. `/dashboard/categories` is a full management workflow: paginated listing,
create/edit forms, hierarchy-safe parent selection, activation with
confirmation, and optional `category-assets` image upload through Server Actions
that re-authorize independently of the dashboard layout. `/dashboard/brands` is
the matching brand workflow: paginated listing, create/edit forms for profile
fields and HTTPS websites, activation with confirmation, and optional
`brand-assets` logo upload. Logos render through the public object URL and are
never inlined as SVG.

Navigation labels never come from raw URL segments or query parameters. Layout
and navigation are not a substitute for authorization inside Server Actions or
Route Handlers.

Extension points for later catalog tasks:

- add a typed entry to `cms/src/lib/navigation/dashboard-routes.ts`;
- place feature UI under `cms/src/features/<area>/` and a matching App Router
  page under `cms/src/app/dashboard/<area>/`;
- reuse `LoadingState`, `EmptyState`, `ErrorState`, and `ConfirmationDialog`
  instead of inventing page-local status patterns.
