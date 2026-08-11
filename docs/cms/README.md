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

This scaffold validates public configuration at startup and exposes no live
Supabase client, auth session, or catalog operation yet.
