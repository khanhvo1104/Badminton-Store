# Migration guide

## Create a migration

```bash
supabase migration new add_something
# edit supabase/migrations/<timestamp>_add_something.sql
```

## Local apply / reset

```bash
supabase start
supabase db reset   # drops local DB, applies all migrations + seed.sql
supabase migration list
supabase db lint
```

## Link remote (careful)

```bash
supabase link --project-ref <ref>
# Review diffs before push
supabase db push   # ONLY with explicit approval for non-prod first
```

**Never** `db reset` a remote production project from this repo.

## Rollback

Prefer a new forward migration that corrects schema.
Do not rewrite already-applied migration files that others may have run.

## CLI note

If Homebrew CLI install fails, a standalone binary may be at `.tools/supabase`.
Docker Desktop is required for local `start` / `db reset`.
