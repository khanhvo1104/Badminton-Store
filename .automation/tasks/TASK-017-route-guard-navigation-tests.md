# TASK-017 — Add route-guard and authenticated navigation regressions

Risk: medium

## Objective

- Make the existing GoRouter auth redirect policy directly testable and add regression coverage for protected deep links and authenticated account navigation without changing the underlying Supabase session boundary.

## Scope

- Extract the current redirect decision into a small pure/testable router policy while preserving `appRouterProvider` behavior and `RouteRefreshNotifier` integration.
- Add focused router/widget tests for session-state redirects, protected account routes, login/logout transitions, and Profile entry points.
- Reuse provider overrides/fakes; no live Supabase/network access.

## Non-goals

- Do not change Supabase Auth, session persistence, login/logout repositories, schema, RLS, grants, configuration, or remote data.
- Do not add role-based/staff routes, remember-and-return deep links, new navigation destinations, or notification backend behavior.
- Do not redesign pages, shell tabs, Profile UI, or router architecture.
- Do not weaken the fail-closed splash behavior for initial/loading/session-error states.
- Do not add dependencies or perform unrelated refactors.

## Allowed paths

- `lib/app/router/`
- `test/app/router/`
- `test/features/authentication/auth_flow_widget_test.dart`
- `test/features/profile/profile_page_test.dart`
- `.automation/backlog.json`

## Acceptance criteria

- Redirect policy is deterministic from `AuthSessionState`, matched location, and debug-route availability; it has no Supabase/client access and exposes no session/user details.
- Initial, loading, and session-error states keep `/splash` and redirect every other tested location to `/splash`.
- Unauthenticated users may remain on `/login`; protected deep links including `/home`, `/profile`, `/orders`, `/addresses`, `/settings`, and `/checkout` redirect to `/login`.
- Authenticated users visiting `/`, `/splash`, or `/login` redirect to `/home`; authenticated protected/account destinations remain unchanged.
- The design-system route stays debug-only and authenticated; the policy preserves current fallback behavior without exposing it in release routes.
- `RouteRefreshNotifier` causes the router to reevaluate when auth state changes; logout from authenticated Settings returns to Login and cannot leave a protected page visible.
- Profile navigation to Orders, Addresses, and Settings remains push-based, reaches the correct route, and back returns to Profile/shell state.
- Unknown routes retain the existing not-found UI and `Go home` action for an authenticated session.
- Tests use real router policy/provider wiring where practical, otherwise focused pure-policy tests; no page repository query or network is required merely to test redirects.
- Existing route paths/names, shell branches, and public APIs remain compatible.

## Required quality gates

- `dart format --output=none --set-exit-if-changed lib/app/router test/app/router test/features/authentication/auth_flow_widget_test.dart test/features/profile/profile_page_test.dart`
- `flutter analyze`
- `flutter test test/app/router test/features/authentication/auth_flow_widget_test.dart test/features/profile/profile_page_test.dart`
- `flutter test`
- `python3 scripts/automation.py policy-check`
