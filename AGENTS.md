# Badminton Store agent rules

These rules apply to every coding agent working in this repository.

## Architecture

- Preserve the feature-first Flutter structure, MVVM boundaries, Riverpod dependency injection, and GoRouter navigation already used by the project.
- Treat `supabase/migrations/` as the database source of truth.
- Never edit a migration that has already been deployed. Create a new migration with the Supabase CLI when a task explicitly requires a schema change.
- Keep changes inside the active task's scope. Do not perform opportunistic refactors.

## Security

- Never read, print, stage, or commit `.env` files, credentials, tokens, private keys, or Supabase secret/service-role keys.
- A Flutter client may contain only a Supabase publishable key (or legacy anon key for compatibility).
- Enable and verify RLS for every table exposed through the Supabase Data API.
- Do not use user-editable metadata for authorization.
- Do not weaken RLS, tests, lint rules, or validation to make a task pass.
- Checkout totals, inventory changes, payment state, and privileged order transitions must be validated server-side.

## Git ownership

- Implementation agents must not commit, push, merge, force-push, alter remotes, or change branches.
- The orchestration controller owns branch creation, commits, pushes, and pull requests.
- Never run destructive Git commands.

## Verification

- Format changed Dart files.
- Run `flutter analyze` and relevant tests.
- Add tests for changed behavior.
- For Supabase changes, run the relevant database/RLS tests and security checks.
- Report blockers honestly; do not claim a check passed unless it was run successfully.

