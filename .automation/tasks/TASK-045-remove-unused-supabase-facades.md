# TASK-045 — Remove unused generic SupabaseDatabase/SupabaseStorage facades

Risk: low

Status: complete

## Objective

- Close readiness-audit **P2-2** by removing the unused generic
  `SupabaseDatabase` / `SupabaseStorage` facade trap.
- Feature repositories already use `SupabaseClient` via `supabaseClientProvider`;
  the unused providers threw `UnimplementedError` if read.

## Scope

- Prove repository-wide that `lib/core/supabase/supabase_database.dart`,
  `lib/core/supabase/supabase_storage.dart`, `supabaseDatabaseProvider`, and
  `supabaseStorageProvider` have no runtime/test consumers beyond
  declarations/docs.
- Delete the dead interfaces and provider declarations (and now-unused imports).
  Do not invent implementations or migrate working repositories.
- Preserve `supabaseClientProvider`, auth/session providers, initialization,
  Riverpod architecture, feature behavior, RLS, and storage boundaries.
- Update architecture/coding/readiness docs (and other direct references) so they
  no longer claim this gap remains.
- Restore TASK-043 / TASK-044 completed backlog/task records if missing from the
  durable queue, using accurate titles/results without rewriting prior history.

## Non-goals

- No implementations of the deleted facades.
- No feature repository migrations.
- No notification provider changes.
- No Supabase schema/migration/hosted/remote changes.
- No CMS/Playwright work unless policy tooling requires it.
- No `.env`, service-role/secret keys, credentials, project link metadata, or
  tokens.

## Allowed paths

- `lib/core/supabase/supabase_database.dart`
- `lib/core/supabase/supabase_storage.dart`
- `lib/core/supabase/supabase_providers.dart`
- `docs/coding_guidelines.md`
- `docs/architecture.md`
- `docs/audits/application-readiness.md`
- `docs/feature_workflow.md`
- `.automation/backlog.json`
- `.automation/tasks/TASK-043-cms-production-readiness-suite.md`
- `.automation/tasks/TASK-044-cms-deployment-operations.md`
- `.automation/tasks/TASK-045-remove-unused-supabase-facades.md`

## Acceptance criteria

- Dead facade files and throw-on-read providers are gone; remaining core
  providers still fail closed / resolve as before.
- Docs no longer list unused generic DB/Storage facades as remaining work.
- Backlog contains completed TASK-043, TASK-044, and TASK-045 records.
- Diff stays small: no secrets, env files, generated artifacts, migrations, CMS
  changes, or unrelated refactors.

## Required quality gates

- `dart format` on changed Dart files
- `flutter analyze`
- Focused Flutter tests covering remaining core Supabase bootstrap/providers
- `flutter test`
- `python3 scripts/automation.py policy-check`
- Do not run local CMS/Playwright unless policy tooling requires it
