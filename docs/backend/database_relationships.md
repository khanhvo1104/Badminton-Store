# Database relationships

| Child | Parent | On delete |
|-------|--------|-----------|
| profiles.id | auth.users.id | CASCADE |
| addresses.user_id | profiles.id | CASCADE |
| categories.parent_id | categories.id | SET NULL |
| products.category_id | categories.id | RESTRICT |
| products.brand_id | brands.id | SET NULL |
| product_variants.product_id | products.id | RESTRICT |
| product_images.product_id | products.id | CASCADE |
| product_images.variant_id | product_variants.id | CASCADE |
| inventory.variant_id | product_variants.id | CASCADE |
| favorites.* | profiles / products | CASCADE |
| carts.user_id | profiles.id | CASCADE |
| cart_items.cart_id | carts.id | CASCADE |
| cart_items.variant_id | product_variants.id | RESTRICT |
| orders.user_id | profiles.id | RESTRICT |
| order_items.order_id | orders.id | CASCADE |
| order_items.product_id | products.id | SET NULL |
| order_items.variant_id | product_variants.id | SET NULL |
| order_status_history.order_id | orders.id | CASCADE |

Order line FKs are nullable so catalog archival does not erase history.
Snapshots (`product_name`, `sku`, `unit_price`, `product_snapshot`) remain.
