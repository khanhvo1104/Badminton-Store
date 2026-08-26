# Checkout security

## Trusted COD checkout RPC

MVP checkout is implemented as a single database RPC:

```sql
public.checkout_cod(
  p_shipping_address_id uuid,
  p_customer_note text default null
) returns uuid
```

Contract:

- **Caller:** `authenticated` only (plus `service_role` for ops). `PUBLIC` and
  `anon` have no `EXECUTE`.
- **Identity:** customer is always `auth.uid()`. The RPC never accepts a user
  ID, role, prices, totals, currency, stock state, order status, or payment
  status from the client.
- **Inputs:** an owned `addresses.id` and an optional note (blank → `NULL`).
- **Payment MVP:** `payment_method = 'cod'`, `payment_status = 'unpaid'`,
  `discount_total = 0`, `shipping_fee = 0`.
- **Return:** only the new `orders.id`. No cost, inventory internals, or
  privileged fields.

## Why Flutter must not trust client totals

Any price or total computed on device can be tampered with. The RPC:

1. Locks the caller's single active authenticated cart (`FOR UPDATE`).
2. Locks cart lines in ascending `(variant_id, id)` order.
3. Re-reads active `product_variants.price` (never `cart_items.unit_price_snapshot`).
4. Locks matching `inventory` rows in ascending `variant_id` order.
5. Validates the full locked set, then reserves stock, inserts `orders` +
   immutable `order_items`, marks the cart `converted`, and emits one
   owner-scoped `order_update` notification in the same transaction.

Insufficient stock (unless that inventory row has `allow_backorder = true`),
empty carts, inactive profiles, cross-user addresses, inactive variants, or
non-active products raise an error and roll everything back—including any
status-history row created by the order insert trigger and any notification
insert attempted in the same transaction.

## Concurrent cart mutations

`checkout_cod` alone cannot stop a concurrent `cart_items` INSERT that starts
while the cart is still `active`, blocks on the parent-row lock, and resumes
after conversion under a stale READ COMMITTED check. A `BEFORE INSERT OR UPDATE`
trigger (`public.cart_items_enforce_active_cart`) takes `FOR UPDATE` on the
parent cart and rechecks `status = 'active'` after waiting, so the insert fails
once checkout has converted the cart. Customer RLS still requires an active
owned cart; the trigger closes the phantom-line race without broadening
order/inventory write policies.

Regression: `supabase/tests/database/03_trusted_cod_checkout_concurrency.sh`.

## Stock reservation

After all lines pass validation:

```
UPDATE inventory
SET quantity_reserved = quantity_reserved + :qty
WHERE variant_id = :id
```

Availability rule before update:

`quantity_on_hand - quantity_reserved >= qty` **or** `allow_backorder = true`.

## Order snapshots

`order_items` store `product_name`, `variant_name`, `sku`, `unit_price`,
`quantity`, `line_total`, `image_path`, and an allowlisted `product_snapshot`
JSON (no `cost_price`, never `to_jsonb(product_variants)`).

`orders.shipping_address` is an immutable JSON snapshot of the chosen address.

## Idempotent retry

A second checkout after cart conversion finds no `active` cart and fails with a
stable "requires an active cart" error. It does not create a duplicate order or
a duplicate `order_update` notification. Concurrent callers serialize on the
cart row lock.

## Keys

- Flutter: publishable / anon key only. Never embed a service-role key.
- Server authority: this SECURITY DEFINER RPC (`set search_path = ''`, fully
  qualified objects). Customer RLS still blocks direct `INSERT`/`UPDATE` on
  `orders`, `order_items`, and `inventory`; do not broaden those policies for
  checkout.

## Flutter status

Checkout UI remains intentionally locked until a later task wires the client to
`checkout_cod`. Display totals in the app are informational only.
