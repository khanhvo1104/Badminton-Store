# ADR-006: Use Next.js for the staff CMS

Status: accepted

## Decision

Build the staff-facing CMS as a TypeScript Next.js App Router application under
`cms/`. It is independently deployable but shares the repository, Supabase
project, migrations, and security contracts with the Flutter storefront.

## Rationale

The CMS is dominated by authenticated forms, tables, search, validation, image
uploads, and responsive administrative UI. Next.js provides the shortest path to
those workflows and has a maintained Supabase SSR integration. Server Components,
Server Actions, and Route Handlers also provide a small server boundary without
requiring a second general-purpose API.

Supabase already provides authentication, Postgres, Data API, Storage, grants,
and RLS. Introducing Go for the initial CMS would duplicate authentication,
authorization plumbing, DTOs, CRUD endpoints, validation, deployment, and
observability before the product requires a dedicated backend service.

## Consequences

- The repository gains an npm workspace-like application with its own lockfile
  and quality gates; the Flutter source layout is not moved.
- Normal CMS operations use the signed-in user's Supabase session and remain
  constrained by RLS.
- Authenticated Next.js routes must not use shared caching or ISR where a session
  can be refreshed.
- `@supabase/ssr` versions are pinned and its implementation is checked against
  current documentation during upgrades.
- Go remains an option for future queue workers, bulk imports, ERP integration,
  or high-throughput webhooks. Such a service would complement, not replace, the
  CMS.

## Rejected alternatives

### Go-rendered CMS plus custom API

Rejected for the initial release because it increases UI and API delivery cost
and duplicates capabilities already enforced by Supabase.

### Flutter Web CMS

Rejected because administrative tables, web forms, browser navigation, and web
deployment benefit from the mature React/Next.js ecosystem, while sharing Dart
code would not remove the need for a distinct authorization and UX boundary.

### Separate repository

Deferred. A separate repository would make database contract changes and their
consumers harder to review atomically. It can be reconsidered if ownership or
release cadence diverges materially.
