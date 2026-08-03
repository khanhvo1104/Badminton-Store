# Flutter integration notes

## Domain ↔ table mapping

| Flutter entity | Table / view |
|----------------|--------------|
| Profile | profiles (`id` = auth user) |
| Address | addresses (VN fields) |
| Category | categories (`imagePath` ← `image_path`) |
| Brand | brands (`logoPath` ← `logo_path`) |
| Product | products (`status`, not boolean alone) |
| ProductVariant | product_variants + availability RPC |
| ProductImage | product_images (`storagePath`) |
| Cart / CartItem | carts / cart_items |
| Order / OrderItem | orders / order_items |

## Naming

Postgres `snake_case` → Dart `camelCase` via Freezed `@JsonKey` when models are added.

## Money

DB `numeric(14,2)` → Dart `double` for VND whole units in domain entities.
Prefer a dedicated money type later; never use binary float for intermediate accounting on the server.

## Catalog reads

Prefer `product_catalog` view and `search_products` / `get_variant_availability` RPCs.
Do not select `cost_price` in client queries.

## Not in this milestone

Repository implementations and PostgREST data sources remain unimplemented.
