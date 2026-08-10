# TASK-010 — Add explicit Supabase configuration failure UX

Risk: medium

## Objective

Fail closed with a clear, non-sensitive startup screen when Supabase URL/key
configuration is missing, instead of starting the normal app and later throwing
from `supabaseClientProvider` or leaving session restore on a loading screen.

## Scope

- Make the bootstrap decision explicit after loading `SupabaseConfig` and before
  the normal authenticated application/provider graph is mounted.
- Render a small production-safe configuration error app/view when the config is
  incomplete. Explain that application configuration is unavailable and how a
  developer/operator can supply it, without echoing URL, key, env contents, or
  other credentials.
- Preserve the existing initialization and `ProviderScope` behavior unchanged
  when configuration is valid.
- Keep `supabaseClientProvider` fail-closed as a defensive invariant; do not
  replace its guard with nullable clients or broad fallback repositories.
- Add focused unit/widget tests for configured and unconfigured startup
  decisions plus the error view copy/semantics.
- Update only readiness-audit P1-5 and the TASK-010 check record.

## Non-goals

- No `.env` reads in tests, and never print or snapshot secrets/config values.
- No Supabase schema, migration, RLS, remote, repository, session, router, or
  feature behavior changes.
- No retry that invents/reloads credentials at runtime; restarting with valid
  configuration is the recovery path.
- No generic application-wide error-boundary redesign.
- Do not weaken `supabaseClientProvider` or silently use fake data.

## Allowed paths

- `lib/app/bootstrap.dart`
- `lib/app/configuration_error_app.dart`
- `test/app`
- `docs/audits/application-readiness.md`

## Acceptance criteria

- Missing URL, missing key, or both select the explicit configuration-error UX
  before the normal `App` and Supabase-dependent providers are mounted.
- The error UX is readable, accessible, deterministic, and contains no supplied
  URL/key values or environment-file contents.
- Valid configuration follows the existing Supabase initialization and normal
  app bootstrap path exactly once.
- Initialization failures are not mislabeled as missing configuration and still
  surface honestly to the existing top-level error handling/logging behavior.
- Tests do not access real `.env` files, networks, Supabase, or credentials.
- Existing auth/session/provider tests continue to pass.

## Required quality gates

- Format changed Dart files.
- `flutter analyze`
- `flutter test test/app`
- `flutter test`
- `python3 scripts/automation.py policy-check`

