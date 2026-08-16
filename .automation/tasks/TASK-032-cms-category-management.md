# TASK-032 — Build CMS category management

Risk: high

## Objective

- Replace the protected `/dashboard/categories` placeholder with a production-ready
  category management workflow for active CMS staff and admins.
- Support bounded listing, creation, editing, hierarchy, activation, ordering,
  descriptions, and optional category images through the existing Supabase table,
  RLS policies, and `category-assets` bucket.

## Existing security contract

- `public.categories` already has RLS enabled. Active rows are publicly readable;
  active staff/admin profiles may read inactive rows and mutate rows through their
  authenticated user JWT.
- `category-assets` is public-read with a 2 MiB bucket limit and allows staff/admin
  INSERT/UPDATE/DELETE for JPEG, PNG, WebP, and SVG objects.
- The CMS uses the cookie-backed `@supabase/ssr` server client with the publishable
  key. Do not introduce a service-role or secret key.
- Existing migrations and executable suites are the database source of truth.
  This task requires no schema or policy change.

## Scope

- Add a server-rendered, explicitly ordered and paginated category list with a
  stable page-size cap, total count, active/inactive status, parent name, sort
  order, image preview, and edit entry point.
- Add create and edit routes/forms for `name`, normalized `slug`, optional
  `description`, optional `parent_id`, integer `sort_order`, and `is_active`.
- Validate all form input again on the server. Return field-safe, sanitized
  failures; never expose raw PostgREST, Storage, SQL, or authorization errors.
- Re-authorize active staff/admin inside every Server Action before querying or
  mutating. The dashboard layout is not the mutation authorization boundary.
- Enforce hierarchy safety before writes: a category cannot parent itself, an edit
  cannot choose any descendant as its parent, and malformed/unknown parent IDs are
  rejected. Traversal must be bounded and cycle-safe even if legacy data is bad.
- Treat slug uniqueness conflicts as a stable user-facing validation failure.
- Allow optional category image upload and replacement in `category-assets` using
  a server-generated object path under the category ID. Validate MIME allow-list,
  non-empty content, and the 2 MiB limit before upload; never trust the submitted
  filename as an object path.
- Compensate partial image failures: do not leave a database row pointing at a
  failed object; delete a newly uploaded object if the database update fails; only
  remove the previous object after the new path is committed. Report cleanup
  failure safely without logging secrets or file contents.
- Revalidate affected category routes after successful mutations and preserve
  accessible pending, validation, empty, error/retry, and success states.

## Non-goals

- Do not add hard-delete, drag-and-drop ordering, bulk operations, product counts,
  brand/product/variant/inventory editing, or a general media library.
- Do not change Flutter, database schema, migrations, RLS/grants, Storage policies,
  bucket configuration, dependencies, CI, authentication, or password recovery.
- Do not use client-side Supabase access for category reads or mutations.

## Allowed paths

- `cms/src/app/dashboard/categories/`
- `cms/src/features/categories/`
- `cms/src/components/ui/`
- `cms/src/lib/auth/`
- `cms/src/lib/errors/`
- `cms/src/lib/supabase/`
- `cms/README.md`
- `docs/cms/`
- `.automation/backlog.json`

## Acceptance criteria

- `/dashboard/categories` replaces the placeholder and reads only explicit category
  columns through the authenticated SSR client; no unbounded `.select('*')` exists.
- Pagination parameters are strictly parsed and clamped. Queries use deterministic
  ordering before the inclusive zero-based Supabase `.range(from, to)` modifier.
- Create/edit forms work without JavaScript, retain non-sensitive submitted values
  after validation failures, expose labels/help/errors accessibly, and disable
  duplicate submission while pending when JavaScript is available.
- Server actions independently reject anonymous, customer, inactive, malformed,
  and recovery sessions without attempting category or Storage writes.
- Name, slug, description, sort order, active state, parent selection, UUIDs, and
  image data are server-validated; field limits align with database constraints.
- Editing a category cannot create self-parent or descendant-parent cycles.
- Activation/deactivation is explicit and requires confirmation; inactive rows stay
  visible to authorized CMS users and remain hidden from public users by existing RLS.
- Slug conflicts and provider failures produce sanitized stable messages and do not
  include SQL, table names, tokens, object internals, or raw provider text.
- Optional images accept only JPEG/PNG/WebP/SVG up to 2 MiB, use generated paths,
  render from the public bucket URL, and follow the compensation sequence in scope.
- Focused network-free tests cover list mapping/pagination, authorization denial,
  input and slug validation, create/edit/activation, hierarchy cycle rejection,
  upload validation, generated paths, replacement ordering, compensation failures,
  sanitized errors, revalidation, and the primary page/form states.
- Existing CMS auth/dashboard tests remain green. No migration or secret file changes.

## Required quality gates

- `cd cms && npm ci`
- `cd cms && npm run format:check`
- `cd cms && npm run lint`
- `cd cms && npm run typecheck`
- `cd cms && npm test -- --run`
- `cd cms && npm run build`
- `flutter analyze`
- `git diff --check`
- `python3 scripts/automation.py policy-check`

## Supabase verification

- Run `supabase --version` and discover relevant commands with `--help`; do not
  guess CLI syntax.
- Run the existing CMS security contract/RLS/Storage regression suite if the local
  Supabase stack is available. If it is unavailable, report the exact blocker and
  rely only on the already-versioned contract tests; do not claim live verification.
- Run `supabase migration list --local` and confirm this task creates no migration.

## Forbidden actions

- Do not read, print, edit, stage, or commit `.env*`, credentials, tokens, private
  keys, service-role keys, or generated build output.
- Do not weaken authorization, RLS, validation, tests, lint, or CI.
- Do not edit a deployed migration or connect tests to production data.
- Do not change branches/remotes, force-push, push to `develop`, or merge/approve
  the implementation pull request as Cursor.
