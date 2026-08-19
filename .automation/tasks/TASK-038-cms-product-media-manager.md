# TASK-038 — Build CMS product media manager

Risk: high

## Objective

- Add a staff/admin-only product media manager on protected product routes.
- Upload, preview, edit, reorder, set primary, replace, and delete product
  images with Storage/database compensation for partial failures.
- Preserve existing `product_images` RLS, Storage policies, and the
  cost/barcode contract.

## Existing security contract

- `public.product_images` already has RLS enabled. Public users may read rows
  for active products; active staff/admin may read all statuses and mutate
  through their authenticated JWT.
- Unique indexes enforce one primary general image per product
  (`variant_id is null`) and one primary per variant.
- `product_images.variant_id` must belong to the same product (trigger).
- `product-images` is public-read with a 5 MiB limit and allows JPEG, PNG,
  WebP, and GIF. Staff/admin may INSERT/UPDATE/DELETE objects. SVG is not an
  allowed bucket MIME type and must never be rendered.
- The CMS uses the cookie-backed `@supabase/ssr` server client with the
  publishable key. Do not introduce a service-role or secret key.

## Scope

- Server-rendered media page at `/dashboard/products/[productId]/media`,
  linked from product detail and editor, with loading/error/not-found states.
- Bounded deterministic image list for the route-bound product. Safe public
  previews from stored paths only. Never render SVG. Never trust form
  `product_id`, `storage_path`, actor, or role.
- Upload validated raster images only (JPEG/PNG/WebP/GIF to match the bucket),
  bounded file size/count, normalized bounded alt text, optional route-bound
  variant association verified to belong to the product, deterministic
  collision-resistant product-scoped object paths, `upsert: false`.
- Create the DB row only after Storage upload succeeds; if DB insert fails,
  best-effort remove the newly uploaded object.
- Edit alt text, variant association, and order. Set primary through a narrow
  RPC that preserves exactly one primary per scope and avoids unique-index
  races.
- Replace safely: upload a new unique object, update the DB path, then
  best-effort delete the old object; on DB failure delete the new object.
- Delete the DB row first, then best-effort Storage delete. Never leave a DB
  row pointing at a missing object. Promote the next remaining image in the
  same scope when deleting a primary.
- Reordering is bounded and route-bound. Sanitize PostgREST/Storage errors.

## Non-goals

- Flutter files, Flutter CI, Flutter analyze/test/build.
- Orders, staff management, a general media library, video, bulk import.
- Editing deployed migrations, weakening RLS/grants/Storage policies.
- Dependency, env, deployment, or remote Supabase migration application.
- Client-side Supabase access for media reads or mutations.

## Allowed paths

- `cms/src/app/dashboard/products/**`
- `cms/src/app/dashboard/dashboard.test.tsx`
- `cms/src/features/media/**`
- `cms/src/features/products/**`
- `cms/src/features/variants/**`
- `cms/src/components/ui/**`
- `cms/src/lib/navigation/dashboard-routes.ts`
- `cms/src/lib/navigation/dashboard-routes.test.ts`
- `cms/src/lib/auth/**`
- `cms/src/lib/errors/**`
- `cms/src/lib/supabase/**`
- `cms/README.md`
- `docs/cms/**`
- `docs/backend/database_schema.md`
- `docs/backend/rls_policies.md`
- `docs/architecture/006-nextjs-cms.md`
- `supabase/migrations/**`
- `supabase/tests/database/**`
- `supabase/README.md`
- `.automation/backlog.json`
- `.automation/tasks/TASK-038-cms-product-media-manager.md`

## Acceptance criteria

- `/dashboard/products/[productId]/media` is staff/admin-only via the dashboard
  layout plus independent Server Action/query authorization.
- Image reads use explicit columns, deterministic `sort_order, id` ordering,
  and a stable page-size cap. Queries fail closed on overflow.
- Server Actions bind `productId` / `imageId` from the validated route and
  never choose the mutation target from FormData `product_id` or
  `storage_path`.
- Uploads reject empty files, oversize files, SVG, and disallowed MIME types.
  Generated paths are `{productId}/{uuid}.{ext}` under `product-images`.
- `set_cms_product_image_primary` and `reorder_cms_product_images` are
  SECURITY INVOKER with empty `search_path`, `is_staff_or_admin()`
  authorization, advisory locks, explicit revoke/grant, and minimal return.
  SECURITY DEFINER is not used because staff already have table UPDATE under
  RLS.
- Delete promotes the next in-scope primary while the row still exists,
  then removes the database row before Storage. Storage cleanup failure
  returns a sanitized warning without provider internals.
- Replace never overwrites an existing object. Partial failures compensate.
- CMS tests cover auth-before-read/write, forged route/form IDs, upload
  validation, generated paths, replacement/delete ordering, compensation,
  sanitized errors, protected-field/response contracts, and UI states.
- DB tests cover staff/admin success; anon/customer/inactive/forged denial;
  cross-product IDs; unique primary invariant; bounded reorder; grants.

## Required quality gates

- Discover Supabase CLI commands via `--help`; create migration via
  `supabase migration new`
- Apply locally; `supabase migration list --local`
- Relevant `01`, `02`, `05`, `07` and new/extended DB tests plus concurrency
- `cd cms && npm ci` if necessary
- `cd cms && npm run format:check`
- `cd cms && npm run lint`
- `cd cms && npm run typecheck`
- `cd cms && npm test -- --run`
- `cd cms && npm run build`
- Do not run Flutter commands
- `git diff --check`
- `python3 scripts/automation.py policy-check`
