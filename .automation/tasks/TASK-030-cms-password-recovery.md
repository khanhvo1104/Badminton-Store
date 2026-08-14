# TASK-030 — Add secure CMS password recovery

Risk: high

## Objective

- Let an existing Supabase user recover and replace a forgotten password entirely through the deployed Next.js CMS, then sign in with the new password.

## Scope

- Add a forgot-password entry point to the CMS login experience.
- Request a Supabase recovery email with an explicit CMS callback URL derived from validated server configuration.
- Exchange the Supabase PKCE recovery code for a server-side session, allow the user to choose a new password, then clear the recovery session and return to login with a non-sensitive success message.
- Add focused tests for actions, redirect validation, route handling, forms, and error states.
- Document the required CMS site URL and Supabase Auth redirect allow-list entry.

## Non-goals

- Do not change Flutter authentication, staff/admin authorization rules, profiles, RLS, database schema, migrations, catalog features, or dashboard functionality.
- Do not use a service-role/secret key, expose auth errors that reveal whether an email exists, accept arbitrary redirect destinations, or log passwords/tokens/recovery codes.
- Do not implement account registration, magic-link login, OAuth, MFA, or administrator-driven password assignment.

## Allowed paths

- `cms/src/app/login/`
- `cms/src/app/forgot-password/`
- `cms/src/app/auth/callback/`
- `cms/src/app/update-password/`
- `cms/src/features/auth/`
- `cms/src/lib/auth/`
- `cms/src/lib/env/`
- `cms/src/lib/supabase/`
- `cms/.env.example`
- `cms/README.md`
- `docs/cms/`
- `.automation/backlog.json`

## Acceptance criteria

- Login exposes a clear “Forgot password?” link without changing the existing password sign-in behavior.
- Submitting a syntactically valid email always returns the same neutral acknowledgement, regardless of whether the account exists; validation and provider failures do not disclose account existence.
- `resetPasswordForEmail` receives an HTTPS production callback under the configured CMS origin; localhost is accepted only in development/test configuration.
- The callback exchanges only a Supabase PKCE `code`, validates `next` against an internal allow-list, rejects missing/invalid codes safely, and never reflects an external URL.
- The update-password page requires a verified recovery session and validates a sufficiently strong password plus confirmation before calling `auth.updateUser`.
- After a successful password change, the recovery session is signed out/cleared and the user is redirected to login with a generic success message; no token, password, or provider error is placed in the URL or logs.
- Existing active staff/admin authorization remains the gate for `/dashboard`; recovery alone does not grant CMS access.
- Configuration failure renders a safe actionable state and never falls back to `localhost` in production.
- Tests cover neutral forgot-password responses, callback success/failure and redirect safety, password validation, update success/failure, session cleanup, and the login recovery link without live network access.
- Documentation specifies the production CMS origin and exact Supabase redirect allow-list callback path.

## Required quality gates

- `cd cms && npm run format:check`
- `cd cms && npm run lint`
- `cd cms && npm run typecheck`
- `cd cms && npm test -- --run`
- `cd cms && npm run build`
- `git diff --check`
- `python3 scripts/automation.py policy-check`
