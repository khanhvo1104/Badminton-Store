# TASK-035 — Build CMS product editor

Risk: high

## Objective

- Add product create/edit/detail routes for core catalog fields only.
- Wire the product explorer to the new editor instead of a disabled affordance.
- Re-authorize active staff/admin inside every Server Action before mutation.
- Use existing RLS/grants only; no migration or policy changes.

## Scope

- Routes: `/dashboard/products/new`, `/dashboard/products/[productId]`, `/dashboard/products/[productId]/edit`.
- Core fields: `category_id`, optional `brand_id`, `name`, `slug`, `short_description`, `description`, `specifications`, `search_keywords`, `status`, `is_featured`, `published_at`.
- Server validation, bounded JSON specifications, slug handling, publication rules, inactive reference rules, sanitized errors, redirect/revalidation, accessible forms, and network-free tests.

## Non-goals

- Variants, prices, inventory, media, delete, duplicate, bulk/import/export.

## Allowed paths

- `cms/src/app/dashboard/products/**`
- `cms/src/features/products/**`
- `cms/src/components/ui/**` only if needed
- `cms/src/lib/auth|errors|supabase/**` only if needed
- `cms/README.md`, `docs/cms/**`
- `.automation/backlog.json`, `.automation/tasks/TASK-035-cms-product-editor.md`

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
