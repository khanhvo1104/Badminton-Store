# Supabase — Badminton Store

Local Supabase database foundation for the Flutter badminton shop.

## Layout

```
supabase/
  config.toml
  migrations/     # ordered SQL migrations
  seed.sql        # demo catalog
  import/         # CSV templates + import README
  tests/database/ # constraint / RLS checklists
  README.md
```

## Prerequisites

- Supabase CLI (`supabase --version`)
- Docker Desktop (required for `supabase start` / `db reset`)

A standalone CLI binary may live at `.tools/supabase` when Homebrew install is blocked.

## Common commands

```bash
# From repo root
./.tools/supabase start          # or: supabase start
./.tools/supabase db reset       # apply migrations + seed
./.tools/supabase migration list
./.tools/supabase db lint
./.tools/supabase status
```

Never run destructive resets against a linked remote production project.

## Flutter env

Use publishable/anon key only:

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Never put `service_role` in Flutter.

## Next steps

1. Install Docker + CLI
2. `supabase db reset`
3. Verify `product_catalog` view returns active products
4. Wire Flutter repositories to PostgREST / RPC
