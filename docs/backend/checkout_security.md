# Checkout security

## Why Flutter must not trust client totals

Any price or total computed on device can be tampered with.
Checkout must:

1. Re-read active variant prices from the database.
2. Recompute `subtotal`, `discount_total`, `shipping_fee`, `grand_total`.
3. Insert `orders` + `order_items` in one transaction via SECURITY DEFINER RPC or Edge Function using the service role **only on the server**.

## Stock reservation

Atomically:

```
UPDATE inventory
SET quantity_reserved = quantity_reserved + :qty
WHERE variant_id = :id
  AND quantity_on_hand - quantity_reserved >= :qty
```

Fail the checkout if the update affects 0 rows (unless `allow_backorder`).

## Order snapshots

`order_items` store `product_name`, `sku`, `unit_price`, `image_path`, `product_snapshot`
so history survives catalog changes.

## Keys

- Flutter: publishable / anon key only.
- Server: service role in Edge Function secrets — never in the app binary.
