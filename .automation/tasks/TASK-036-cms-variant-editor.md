# TASK-036 — Build CMS variant editor

Risk: high

## Objective

- Add per-product variant list, create, and edit routes for SKUs, attributes,
  selling prices, compare-at prices, the protected cost contract, defaults, and
  uniqueness.
- Link product detail/editor to the variant editor.
- Re-authorize active staff/admin inside every mutation Server Action before any
  operational read/write.
- Add one SECURITY INVOKER save/upsert RPC for create/update and atomic default
  switching, without weakening existing RLS or column grants.

## Scope

- Routes: `/dashboard/products/[productId]/variants`, `/variants/new`,
  `/variants/[variantId]/edit`.
- List a bounded, explicitly selected set of variants for one product with text
  status/default, SKU/name, attributes, selling price, compare-at price,
  protected cost, unit, and sort order.
- Create/edit fields: sku, optional name, color_name, optional `#RRGGBB`
  color_hex, racket_weight_class, grip_size, shoe_size, clothing_size, unit,
  price, optional compare_at_price, optional cost_price, optional barcode,
  bounded nested attributes JSON, is_default, is_active, sort_order.
- Cookie-backed SSR user JWT only. Costs read only through
  `get_staff_variant_costs`. Barcode is not prefilled; edit preserves it unless
  staff set or clear it through the RPC contract.
- One new CLI-created migration defining `save_cms_product_variant`.

## Non-goals

- Inventory adjustment, product core mutation, images/media, delete,
  bulk/import/export.
- Direct `cost_price` SELECT, barcode SELECT grant expansion, service-role CMS
  clients, Flutter/CI/lockfile changes.

## Allowed paths

- `cms/src/app/dashboard/products/**`
- `cms/src/features/products/**`
- `cms/src/features/variants/**`
- `cms/src/components/ui/**`
- `cms/src/lib/auth|errors|supabase/**`
- `cms/README.md`
- `docs/cms/**`
- `supabase/migrations/**`
- `supabase/tests/database/**`
- `.automation/backlog.json`
- `.automation/tasks/TASK-036-cms-variant-editor.md`

## Acceptance criteria

- Product detail/editor link to variants. List/create/edit are
  responsive/accessible with loading, not-found, and sanitized errors.
- Server Actions bind `productId`/`variantId` from validated route arguments
  and never choose the mutation target from FormData.
- RPC is SECURITY INVOKER, empty `search_path`, fixed SQL, authorizes via
  `is_staff_or_admin()`, validates ownership, switches defaults atomically,
  returns only `variant_id`, and is granted to authenticated/service_role only.
- First variant becomes default. Editing the current default with
  `is_default=false` is rejected.
- Executable DB tests cover grants, staff/admin success, customer/inactive/
  forged/anon denial, cross-product update denial, cost/barcode not returned,
  SKU/barcode uniqueness, compare >= price, atomic default transition, and
  concurrency/rollback.
- Network-free CMS tests cover route binding/forgery, auth-before-read/write,
  list merge, money, JSON attacks, allowlist, duplicate sanitization, cost
  null/zero/preserve/clear/set, default behavior, and page/form states.

## Required quality gates

- Discover Supabase CLI commands via `--help`; create migration via
  `supabase migration new`
- Apply locally; `supabase migration list --local`
- Relevant `01`, `02`, `05`, `07` and new/extended DB tests
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
