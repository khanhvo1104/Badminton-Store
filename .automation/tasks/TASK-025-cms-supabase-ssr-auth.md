# TASK-025 — Add Supabase SSR authentication to the CMS

Risk: high

## Objective

- Add secure cookie-based Supabase authentication to the Next.js CMS so only
  active `staff` and `admin` profiles can access its protected dashboard.

## Scope

- Install pinned, lockfile-resolved `@supabase/supabase-js` and
  `@supabase/ssr` dependencies.
- Add separate browser, server, and Proxy Supabase client utilities using only
  the existing public URL and publishable key configuration.
- Add a Next.js 16 `proxy.ts` flow that refreshes sessions with
  `supabase.auth.getClaims()`, forwards refreshed request/response cookies, and
  preserves the cache-control headers supplied by the current SSR package.
- Add email/password login and logout flows, accessible pending/error states,
  protected dashboard UX, and an unauthorized page.
- Centralize server-side identity/profile authorization in a data-access helper
  that validates claims and reads only `id`, `full_name`, `role`, and
  `is_active` from the caller's own `profiles` row.
- Add network-free unit/component/route tests with injected or mocked Supabase
  boundaries for session refresh, login/logout, redirects, role checks, and
  sanitized failures.
- Update CMS documentation for the authentication flow and first-admin
  prerequisite.

## Authorization contract

- `supabase.auth.getClaims()` validates identity for protected requests; do not
  authorize from `getSession()` or an unverified cookie payload.
- Authorization comes only from the trusted database row
  `public.profiles.role` plus `is_active`; never use `user_metadata`, form data,
  query parameters, or client state as an authority.
- Active `staff` and active `admin` profiles are allowed. Anonymous users go to
  login. Customers, inactive profiles, missing profiles, and unsupported roles
  go to the same sanitized unauthorized experience.
- Proxy is an optimistic session-refresh boundary only. Every protected page,
  Server Action, and Route Handler must independently enforce its required
  authorization.
- Normal CMS access uses the signed-in user's JWT and remains subject to grants
  and RLS.

## Non-goals

- Do not add signup, password reset, magic link, OAuth, MFA, invitations, staff
  creation, role editing, impersonation, remember-me, or account recovery.
- Do not add catalog CRUD, dashboard analytics, generated database types,
  Storage operations, migrations, RLS/grant/function changes, live Supabase
  tests, deployment, or new secrets.
- Do not create a service-role/secret-key client or put any non-publishable
  credential in browser code, example env files, tests, logs, or PR text.
- Do not trust `user_metadata`, `app_metadata`, raw JWT role-like claims, or UI
  visibility for CMS authorization.
- Do not enable ISR or shared caching on authenticated routes or responses that
  can refresh/set authentication cookies.

## Allowed paths

- `cms/`
- `README.md`
- `docs/cms/README.md`
- `docs/cms/security.md`
- `.automation/backlog.json`

## Acceptance criteria

- `@supabase/supabase-js` and `@supabase/ssr` are installed with the updated
  `cms/package-lock.json`; no deprecated auth-helper package is present.
- Browser and server client factories use only validated
  `NEXT_PUBLIC_SUPABASE_URL` and
  `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`; no service-role, secret-key, or direct
  database credential contract is introduced.
- `cms/src/proxy.ts` follows the installed Next.js 16 and current Supabase SSR
  cookie APIs, calls `getClaims()` to refresh/validate the session, writes
  refreshed cookies to both the forwarded request and browser response, applies
  package-provided response headers, and excludes static/image/favicon assets
  with a statically analyzable matcher.
- The public `/login` page provides labelled email/password inputs, native
  autocomplete attributes, disabled/pending behavior, and a Server Action that
  validates trimmed input before calling `signInWithPassword`.
- Login failures expose only stable generic copy; they never echo passwords,
  tokens, Supabase/backend messages, SQL, stack traces, or configuration values.
- A successful login redirects only to the fixed protected dashboard route;
  user-controlled return URLs or external redirects are not accepted.
- The protected dashboard validates claims, queries an explicit safe profile
  projection scoped to the verified subject, and permits only active `staff` or
  `admin`. It greets the user without exposing unnecessary profile fields.
- Anonymous access redirects to `/login`; customer, inactive, missing, and
  malformed profile results render the same sanitized `/unauthorized` outcome.
- Authenticated access is request-time/dynamic and is not cached through ISR or
  a shared public cache.
- Logout is a POST-backed Server Action or Route Handler, validates current
  identity before signing out, clears the SSR session, and redirects to login;
  GET requests cannot log a user out.
- The landing/root route has deterministic session-aware navigation without
  becoming an authorization boundary or creating a redirect loop.
- Tests run without live network/Supabase credentials and cover client cookie
  propagation, header propagation, claims failure, valid staff/admin, customer,
  inactive/missing/malformed profile, login validation/sanitization/success,
  logout, protected-route redirects, root routing, and accessible UI states.
- CMS documentation explains the browser/server/Proxy split, trusted profile
  role source, local configuration, no-self-signup policy, and one-time manual
  creation/promotion prerequisite for the first active admin.
- Existing CMS and Flutter CI behavior remains compatible.

## Required quality gates

- `cd cms && npm ci`
- `cd cms && npm run format:check`
- `cd cms && npm run lint`
- `cd cms && npm run typecheck`
- `cd cms && npm test -- --run`
- `cd cms && npm run build`
- `git diff --check`
- `python3 scripts/automation.py policy-check`
