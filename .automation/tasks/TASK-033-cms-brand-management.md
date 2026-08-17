# TASK-033 — Build CMS brand management

Risk: high

## Objective

- Replace the protected `/dashboard/brands` placeholder with a production-ready
  brand management workflow for active CMS staff and admins.
- Support bounded listing, creation, editing, activation, ordering, brand profile
  fields, and optional logos through the existing Supabase table, RLS policies,
  and `brand-assets` bucket.

## Existing security contract

- `public.brands` already has RLS enabled. Active rows are publicly readable;
  active staff/admin profiles may read inactive rows and mutate rows through their
  authenticated user JWT.
- The table contains `id`, `name`, unique `slug`, optional `description`, optional
  `logo_path`, optional `website_url`, optional `country_of_origin`, `sort_order`,
  `is_active`, and timestamps. Only slug has a database uniqueness constraint.
- `brand-assets` is public-read with a 2 MiB bucket limit and allows staff/admin
  INSERT/UPDATE/DELETE for JPEG, PNG, WebP, and SVG objects.
- The CMS uses the cookie-backed `@supabase/ssr` server client with the publishable
  key. Do not introduce a service-role or secret key.
- Existing migrations and executable suites are the database source of truth.
  This task requires no schema or policy change.

## Scope

- Add a server-rendered, explicitly ordered and paginated brand list with a stable
  page-size cap, total count, active/inactive status, country, website, sort order,
  logo preview, and edit entry point.
- Add create and edit routes/forms for `name`, normalized `slug`, optional
  `description`, optional absolute HTTPS `website_url`, optional
  `country_of_origin`, integer `sort_order`, and `is_active`.
- Validate all form input again on the server. Return field-safe, sanitized
  failures; never expose raw PostgREST, Storage, SQL, or authorization errors.
- Re-authorize active staff/admin inside every Server Action before querying or
  mutating. The dashboard layout is not the mutation authorization boundary.
- Treat the database-enforced slug uniqueness conflict as a stable user-facing
  validation failure. Do not claim or implement race-prone name uniqueness because
  the current schema does not enforce it.
- Allow optional logo upload and replacement in `brand-assets` using a
  server-generated object path under the brand ID. Validate MIME allow-list,
  non-empty content, and the 2 MiB limit before upload; never trust the submitted
  filename as an object path and never render SVG inline.
- Compensate partial logo failures: do not leave a database row pointing at a
  failed object; delete a newly uploaded object if the database write fails; only
  remove the previous object after the new path is committed. Report cleanup
  failure safely without logging secrets or file contents.
- Require explicit confirmation before activation/deactivation, revalidate affected
  brand routes after successful mutations, and preserve accessible pending,
  validation, empty, error/retry, and success states.
- Reuse established category-management patterns where they remain correct, but
  keep brand logic in the feature-first `brands` boundary; do not couple brand
  actions to category-specific constants, types, or components.

## Non-goals

- Do not add hard-delete, drag-and-drop ordering, bulk operations, product counts,
  product/variant/inventory editing, or a general media library.
- Do not add name uniqueness, website reachability checks, country reference data,
  or changes to product-brand relationships.
- Do not change Flutter, database schema, migrations, RLS/grants, Storage policies,
  bucket configuration, dependencies, CI, authentication, or password recovery.
- Do not use client-side Supabase access for brand reads or mutations.

## Allowed paths

- `cms/src/app/dashboard/brands/`
- `cms/src/features/brands/`
- `cms/src/components/ui/`
- `cms/src/lib/auth/`
- `cms/src/lib/errors/`
- `cms/src/lib/supabase/`
- `cms/src/app/dashboard/dashboard.test.tsx`
- `cms/README.md`
- `docs/cms/`
- `.automation/backlog.json`

## Acceptance criteria

- `/dashboard/brands` replaces the placeholder and reads only explicit brand
  columns through the authenticated SSR client; no unbounded `.select('*')` exists.
- Pagination parameters are strictly parsed and clamped. Queries use deterministic
  ordering before the inclusive zero-based Supabase `.range(from, to)` modifier.
- Create/edit forms work without JavaScript, retain non-sensitive submitted values
  after validation failures, expose labels/help/errors accessibly, and disable
  duplicate submission while pending when JavaScript is available.
- Server Actions independently reject anonymous, customer, inactive, malformed,
  and recovery sessions without attempting brand or Storage writes.
- Name, slug, description, HTTPS website URL, country, sort order, active state,
  UUIDs, and logo data are server-validated; field limits align with database and
  bounded application constraints.
- Activation/deactivation is explicit and requires confirmation; inactive rows stay
  visible to authorized CMS users and remain hidden from public users by existing RLS.
- Slug conflicts and provider failures produce sanitized stable messages and do not
  include SQL, table names, tokens, object internals, or raw provider text.
- Optional logos accept only JPEG/PNG/WebP/SVG up to 2 MiB, use generated paths,
  render through the public bucket URL without inline SVG, and follow the required
  compensation sequence.
- Focused network-free tests cover list mapping/pagination, authorization denial,
  input/URL/slug validation, create/edit/activation, upload validation, generated
  paths, replacement ordering, compensation failures, sanitized errors,
  revalidation, and primary page/form states.
- Existing CMS auth/dashboard/category tests remain green. No migration, dependency,
  Flutter, secret, or generated-output changes are present.

## Required quality gates

- `cd cms && npm ci`
- `cd cms && npm run format:check`
- `cd cms && npm run lint`
- `cd cms && npm run typecheck`
- `cd cms && npm test -- --run`
- `cd cms && npm run build`
- `flutter analyze`
- `flutter test`
- `git diff --check`
- `python3 scripts/automation.py policy-check`

## Supabase verification

- Run `supabase --version` and discover relevant commands with `--help`; do not
  guess CLI syntax.
- Run the existing CMS security contract/RLS/Storage regression suite if the local
  Supabase stack is available. If unavailable, report the exact blocker and rely
  only on already-versioned contract tests; do not claim live verification.
- Run `supabase migration list --local` and confirm this task creates no migration.

## Forbidden actions

- Do not read, print, edit, stage, or commit `.env*`, credentials, tokens, private
  keys, service-role keys, or generated build output.
- Do not weaken authorization, RLS, validation, tests, lint, or CI.
- Do not edit a deployed migration or connect tests to production data.
- Do not change branches/remotes, force-push, push to `develop`, or merge/approve
  the implementation pull request as Cursor.
