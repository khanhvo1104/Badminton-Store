# Catalog seed data

## Scope

Seeds **catalog only**:

- categories, brands, products, product_variants, product_images, inventory

Does **not** seed auth users, profiles, carts, favorites, or orders.

## Source of truth

| Artifact | Role |
|----------|------|
| `scripts/generate_catalog_seed.py` | Single generator |
| `supabase/seed.sql` | Applied on `supabase db reset` |
| `supabase/migrations/20260728110000_seed_initial_catalog.sql` | Optional data migration for remote push |
| `supabase/import/*.csv` | Same dataset for Dashboard / COPY |

Regenerate all outputs:

```bash
python3 scripts/generate_catalog_seed.py
```

## Deterministic UUID convention

| Entity | Prefix |
|--------|--------|
| categories | `10000000-0000-4000-8000-…` |
| brands | `20000000-0000-4000-8000-…` |
| products | `30000000-0000-4000-8000-…` |
| variants | `40000000-0000-4000-8000-…` |
| images | `50000000-0000-4000-8000-…` |

## Counts (current generator)

- Categories: **10** (Vietnamese slugs, e.g. `vot-cau-long`)
- Brands: **8**
- Products: **24** — active 19, draft 2, inactive 2, archived 1
- Featured active: **6**
- Variants: **63**
- Images: **32** (placeholder Storage paths)
- Inventory: **63** (includes low-stock, out-of-stock, backorder)

## SKU convention

Examples:

- `RKT-YON-AS88-BLK-4U-G5`
- `SHO-MIZ-CFP-WHT-42`
- `STR-CTL-066-WHT`
- `GRP-COM-DRY-BLK-P3`

## Local run

```bash
supabase start
# Fresh local stack applies migrations (including optional catalog data
# migration) then supabase/seed.sql.
# If db reset fails on older tooling, stop --no-backup and start again.

docker exec -i supabase_db_Badminton-Store \
  psql -U postgres -d postgres < supabase/import/verify_seed_data.sql
```

Studio: http://127.0.0.1:54323

## Clear only seed rows

```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  -f supabase/import/clear_catalog_seed.sql
```

## Remote insert (manual — not auto-pushed)

After linking and reviewing:

```bash
# Option A: push the optional data migration (idempotent upserts)
supabase db push

# Option B: run seed SQL against remote connection string
psql "$REMOTE_DATABASE_URL" -f supabase/seed.sql
```

Verify remote:

```sql
select status, count(*) from public.products
where id::text like '30000000-%'
group by status;
```

## Seed.sql vs migration

- **seed.sql**: local/dev reset only (configured in `config.toml`).
- **Data migration**: only if you explicitly want catalog demo data on remote via `db push`.

## Storage images

Paths are placeholders. Upload later to buckets:

- `product-images`, `brand-assets`, `category-assets`

## Replacing demo with real products

1. Clear seed ranges (`clear_catalog_seed.sql`) or use new UUID namespaces.
2. Import real CSVs / admin UI.
3. Keep SKUs and slugs unique.
