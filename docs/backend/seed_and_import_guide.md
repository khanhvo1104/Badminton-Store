# Seed and import guide

See the detailed catalog seed guide:

- [seed_data_catalog.md](seed_data_catalog.md)
- [Import README](../../supabase/import/README.md)

## Quick local commands

```bash
python3 scripts/generate_catalog_seed.py
supabase db reset
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  -f supabase/import/verify_seed_data.sql
```

## Current catalog seed (generated)

| Entity | Count |
|--------|------:|
| Categories | 10 |
| Brands | 8 |
| Products | 24 (19 active, 2 draft, 2 inactive, 1 archived) |
| Variants | 63 |
| Images | 32 (Storage path placeholders) |
| Inventory | 63 |

## CSV import order

1. categories → 2. brands → 3. products → 4. product_variants → 5. product_images → 6. inventory

## Regenerating

Single source: `scripts/generate_catalog_seed.py` writes `seed.sql`, CSVs, and optional migration `20260728110000_seed_initial_catalog.sql`.
