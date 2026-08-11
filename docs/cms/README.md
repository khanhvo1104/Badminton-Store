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
