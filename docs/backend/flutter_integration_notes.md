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

## Checkout (COD MVP)

Flutter calls only the trusted RPC:

```text
rpc('checkout_cod', params: {
  'p_shipping_address_id': <owned address uuid>,
  'p_customer_note': <trimmed note or null>,
})
```

Rules:

- Authenticated publishable/anon session only. Never embed a service-role key.
- Payload keys are exactly `p_shipping_address_id` and `p_customer_note`.
- Blank / whitespace notes normalize to `null` before the call.
- Do not send user ID, cart ID, prices, totals, currency, inventory, payment
  status, order status, or role.
- Displayed cart line prices and subtotals are **estimates only**. The RPC
  re-reads active variant prices, validates stock, and computes authoritative
  totals server-side.
- Repository failures are mapped to sanitized `AppException` codes; UI shows
  Vietnamese actionable copy and must not interpolate raw PostgREST/SQL text.
- On success, invalidate cart/order providers and navigate to order history
  (`/orders`) or catalog; keep a durable success state that shows the returned
  order UUID if navigation is interrupted.

See also `docs/backend/checkout_security.md`.
