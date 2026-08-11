# TASK-027 — Build the CMS dashboard shell

Risk: medium

## Objective

- Turn the protected CMS dashboard into a responsive, accessible application
  shell with reusable navigation and page-state patterns for the catalog
  management tasks that follow.

## Scope

- Add a protected dashboard layout with desktop sidebar, mobile navigation,
  skip link, breadcrumbs, current-page treatment, signed-in profile context,
  and POST-backed logout control.
- Add a lightweight dashboard overview that communicates the CMS scope and
  links only to routes that exist in this task.
- Add protected placeholder route pages for categories, brands, products, and
  inventory so the primary navigation is functional before their CRUD tasks.
- Add reusable, accessible loading, empty, error/retry, and confirmation-dialog
  primitives with focused component tests.
- Add route-level loading and error experiences for the dashboard segment.
- Update CMS documentation for the shell structure and extension points.

## Architecture contract

- Keep pages/layouts as Server Components by default. Isolate only navigation
  interactions, pathname-derived state, error reset, and confirmation behavior
  into small Client Components.
- Protected entry points use the existing `authorizeCmsRequest` and the
  user-scoped Supabase server client. Layout/navigation is not a replacement
  for authorization in future Server Actions or Route Handlers.
- Authenticated dashboard rendering remains request-time/dynamic and must not
  use ISR, shared public caching, a service-role client, or browser-stored
  profile authority.
- Pass only serializable safe profile fields required by the shell. Never trust
  route labels, user metadata, query parameters, or client state for roles.
- Navigation and breadcrumbs come from one typed route definition rather than
  parsing arbitrary URL text into labels. Unknown descendants fall back to a
  stable safe label and must not echo attacker-controlled text.

## Non-goals

- Do not implement category, brand, product, variant, inventory, media, order,
  analytics, or staff-management data reads/mutations in this task.
- Do not add Supabase migrations, grants, RLS, Storage operations, generated DB
  types, service-role keys, new authentication methods, or remote changes.
- Do not add a UI framework/icon dependency solely for this shell; use the
  existing React, Next.js, Tailwind, and semantic HTML baseline.
- Do not create fake metrics, live charts, unbounded queries, decorative dead
  links, GET logout, or client-only authorization.
- Do not duplicate the full auth implementation or weaken sanitized error and
  unauthorized behavior from TASK-025.

## Allowed paths

- `cms/`
- `README.md`
- `docs/cms/README.md`
- `docs/cms/system-architecture.md`
- `.automation/backlog.json`

## Acceptance criteria

- `/dashboard` and its placeholder children render inside one protected shell
  for active staff/admin only; anonymous and unauthorized behavior remains the
  sanitized TASK-025 contract without redirect loops.
- Desktop navigation is persistent. Mobile navigation has an explicit labelled
  open/close control, closes on route selection and Escape, restores sensible
  focus, prevents hidden controls from remaining keyboard-accessible, and does
  not require hover to operate.
- The shell includes a first-focusable skip link targeting one unique main
  landmark, a visible page heading, semantic navigation labels, keyboard-visible
  focus, and current-page `aria-current` state.
- Breadcrumbs use the typed known-route map, render valid hierarchy/current
  state, and never display raw unknown path segments or search parameters.
- Account context shows only safe display name fallback and trusted staff/admin
  role label. Logout reuses the existing POST Server Action and exposes a clear
  pending/disabled state without changing its security behavior.
- The dashboard overview contains honest static orientation/quick-access cards;
  it does not claim live totals or fetch business data. Every actionable link
  resolves to one of the protected placeholder routes delivered here.
- Category, brand, product, and inventory placeholders each have stable heading,
  breadcrumb/current navigation behavior, and an explicit upcoming-task empty
  state; they perform no catalog query or mutation.
- Shared loading/skeleton, empty, sanitized error/retry, and confirmation-dialog
  components have clear APIs, semantic status/dialog behavior, accessible names,
  initial/focus-return behavior where applicable, Escape/cancel handling, and no
  backend detail leakage.
- Dashboard `loading.tsx` and `error.tsx` use the shared patterns. The error
  boundary is a Client Component and retry calls its supplied `reset` callback.
- Client hooks/components obey App Router boundaries: no async Client Component,
  no non-serializable Server-to-Client props, and pathname-dependent UI has an
  appropriate stable fallback/Suspense boundary where required.
- Network-free tests cover staff/admin shell rendering, existing auth redirects,
  route definitions/breadcrumb fallbacks, desktop/mobile navigation keyboard
  behavior, skip link/main landmark, logout pending state, placeholder routes,
  reusable page states, confirmation cancel/confirm/focus return, and dashboard
  loading/error retry behavior.
- Existing CMS authentication tests and Flutter CI remain compatible.

## Required quality gates

- `cd cms && npm ci`
- `cd cms && npm run format:check`
- `cd cms && npm run lint`
- `cd cms && npm run typecheck`
- `cd cms && npm test -- --run`
- `cd cms && npm run build`
- `git diff --check`
- `python3 scripts/automation.py policy-check`
