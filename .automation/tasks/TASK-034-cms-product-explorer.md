# TASK-034 — Build CMS product explorer

Risk: high

## Objective

- Replace the protected `/dashboard/products` placeholder with a production-ready,
  read-only product explorer for active CMS staff and admins.
- Provide bounded server-side pagination, search, filters, sorting, product status,
  selling-price range, variant counts, primary media, and staff-safe inventory
  summaries without exposing protected cost data or performing unbounded reads.

## Existing security and data contract

- `public.products` has RLS enabled. Public actors can read active products; active
  staff/admin profiles can read every status through their authenticated user JWT.
- Products reference `categories` and optional `brands`. Status is one of `draft`,
  `active`, `inactive`, or `archived`; active products require `published_at`.
- `product_variants` stores SKU and selling prices. The authenticated role has an
  explicit column-level SELECT grant that excludes `cost_price`, `barcode`, and
  timestamps. Do not query, infer, log, or expose `cost_price` in this task.
- `inventory` is staff-only through RLS and grants. It contains on-hand, reserved,
  reorder level, and backorder fields per variant. Inventory figures shown by the
  explorer are operational staff data and must remain server-rendered.
- `product_images` stores paths in the public `product-images` bucket. The explorer
  may display the deterministic primary general image (`variant_id is null` and
  `is_primary is true`) through a public object URL; SVG must never be rendered
  inline.
- Existing explicit grants and RLS/security-contract tests are the source of truth.
  No schema, view, RPC, policy, grant, bucket, or migration change is required.

## Scope

- Add a server-rendered product table/card explorer under `/dashboard/products`
  with explicit columns for product identity, name/slug, category, optional brand,
  status, featured flag, publication/update time, primary image, active/total
  variant count, selling-price range, and aggregate inventory summary.
- Define inventory summary precisely across the variants returned for each product:
  total on hand, total reserved, non-negative available quantity
  `max(on_hand - reserved, 0)`, and low-stock indication when any inventory row has
  available quantity at or below its `reorder_level`. Missing inventory rows must
  be represented explicitly and must not be silently treated as known zero stock.
- Support strict URL query parameters for page, normalized search text, category,
  brand, status, stock state, and sort. Invalid UUID/enums/page values must fall
  back to stable safe defaults rather than being passed to PostgREST.
- Search product name and slug with escaped literal user input. Do not construct a
  raw PostgREST filter expression from attacker-controlled text. Bound the accepted
  search length and keep submitted filters in the URL for shareable navigation.
- Support deterministic sort options for newest updated, oldest updated, name A-Z,
  name Z-A, price low-high, and price high-low. Every ordering must include `id` as
  a stable final tie-breaker. Price sorts must define deterministic placement for
  products without variants/prices.
- Populate category and brand filters with bounded, explicitly selected and ordered
  reference reads visible to authorized CMS users, including inactive references
  so existing draft/inactive products remain discoverable.
- Use a bounded query plan: fetch only the requested product page and then fetch
  related variants, inventory, and primary images only for IDs from that page.
  Batch/relational reads are allowed; per-row N+1 queries and unbounded fallback
  reads are forbidden. Supabase `.range(from, to)` is zero-based and inclusive and
  must follow deterministic ordering.
- Keep all Supabase access in Server Components/server-only feature queries using
  the cookie-backed SSR client and user JWT. Authorize with `authorizeCmsRequest`
  before operational inventory reads. Return narrow mapped DTOs and sanitized,
  stable load failures without raw provider/SQL details.
- Add accessible filter/search controls with an explicit submit action and clear
  link, status/stock text not conveyed by color alone, responsive overflow handling,
  loading skeleton, empty results state, and retryable error boundary.
- Link each result to the future product editor route without implementing the
  editor. If the destination remains unavailable, use a clearly disabled/non-link
  affordance instead of shipping a broken navigation path.
- Update CMS documentation and stale dashboard navigation copy to describe the
  delivered Product Explorer accurately.

## Non-goals

- Do not create, edit, publish, archive, activate, delete, duplicate, import, or
  bulk-update products.
- Do not mutate variants, prices, inventory, media, categories, or brands.
- Do not implement product detail/editor, variant editor, inventory adjustments,
  media management, CSV export/import, dashboards, or analytics.
- Do not add fuzzy search, a new search RPC/view, database aggregate function,
  schema/index optimization, dependencies, or client-side Supabase access.
- Do not change Flutter, authentication, password recovery, CI, migrations, RLS,
  grants, Storage policies, or bucket configuration.

## Allowed paths

- `cms/src/app/dashboard/products/`
- `cms/src/features/products/`
- `cms/src/components/ui/`
- `cms/src/lib/auth/`
- `cms/src/lib/errors/`
- `cms/src/lib/navigation/dashboard-routes.ts`
- `cms/src/lib/navigation/dashboard-routes.test.ts`
- `cms/src/lib/supabase/`
- `cms/src/app/dashboard/dashboard.test.tsx`
- `cms/README.md`
- `docs/cms/`
- `.automation/backlog.json`

## Acceptance criteria

- `/dashboard/products` replaces the placeholder and is available only through the
  existing active staff/admin authorization boundary.
- Product, category, brand, variant, inventory, and image reads select explicit
  columns only. There is no `.select('*')`, service-role client, protected cost
  field, client-side Supabase request, N+1 loop, or unbounded related-data query.
- Pagination is strictly parsed/clamped, total count drives valid navigation, and
  every paged/sorted query uses deterministic order with an `id` tie-breaker before
  the inclusive `.range(from, to)` modifier.
- Search is length-bounded and safely escaped/encoded; crafted commas, parentheses,
  percent signs, underscores, quotes, and PostgREST operators cannot alter filter
  structure or expose products outside the intended staff query.
- Category, brand, status, stock, page, and sort filters round-trip through the URL,
  combine correctly, have safe defaults, and offer an accessible clear/reset path.
- Each row renders category, optional brand, all product statuses, featured state,
  primary image/fallback, variant counts, price range, and the specified inventory
  summary. Missing price/inventory data is distinguishable from numeric zero.
- Price and inventory values use locale-safe presentation without floating-point
  business calculations; malformed provider rows fail through a sanitized stable
  state rather than leaking raw data or rendering misleading totals.
- Loading, empty, filtered-empty, error/retry, and populated states are responsive
  and accessible; status and stock meaning is available as text and not color-only.
- Focused network-free tests cover query parsing, search escaping, each filter and
  sort contract, zero-based inclusive ranges, stable tie-breakers, bounded related
  reads, mapping/aggregation, null/missing data, sanitization, authorization, and
  primary page/filter/list states.
- Existing CMS auth/dashboard/category/brand tests remain green. No migration,
  dependency, Flutter, secret, or generated-output change is present.

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
- Run the existing CMS security contract/RLS regression suite if the local
  Supabase stack is available. If unavailable, report the exact blocker and rely
  only on versioned contract tests; do not claim live verification.
- Run `supabase migration list --local` and confirm this task creates no migration.

## Forbidden actions

- Do not read, print, edit, stage, or commit `.env*`, credentials, tokens, private
  keys, service-role keys, protected cost values, or generated build output.
- Do not weaken authorization, RLS, grants, validation, tests, lint, or CI.
- Do not edit a deployed migration or connect tests to production data.
- Do not change branches/remotes, force-push, push to `develop`, or merge/approve
  the implementation pull request as Cursor.
