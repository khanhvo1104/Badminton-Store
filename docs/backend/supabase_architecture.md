# Supabase architecture

## Stack

- PostgreSQL (Supabase)
- Auth (`auth.users` → `public.profiles`)
- Storage buckets for catalog + avatars
- RLS on every application table
- Migrations via Supabase CLI

## Boundaries

| Layer | Responsibility |
|-------|----------------|
| Flutter | UI, local guest cart, publishable key only |
| PostgREST / RPC | Catalog reads, customer CRUD for addresses/favorites/cart |
| Future Edge Function / RPC | Checkout: re-price, reserve stock, insert order |

## Money

All amounts are `numeric(14,2)` with `currency_code` default `VND`.
Never use floating binary types for money.

## Search (MVP)

`products.search_vector` (generated tsvector on name + keywords) plus
`search_products(query)` RPC with `ilike` fallbacks on brand/category names.

## Promotions / reviews / multi-warehouse

Deferred. Schema leaves room via jsonb attributes and future tables;
do not add a full promo engine in this milestone.
