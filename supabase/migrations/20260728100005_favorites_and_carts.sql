-- Favorites and shopping carts.

create table public.favorites (
  user_id uuid not null references public.profiles (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, product_id)
);

comment on table public.favorites is
  'Wishlist. Composite PK (user_id, product_id).';

create index favorites_product_id_idx on public.favorites (product_id);

create table public.carts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id) on delete cascade,
  guest_token uuid,
  status text not null default 'active',
  currency_code text not null default 'VND',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz,
  constraint carts_status_check
    check (status in ('active', 'converted', 'abandoned', 'expired')),
  constraint carts_currency_check
    check (char_length(currency_code) = 3),
  constraint carts_owner_xor_check
    check (
      (user_id is not null and guest_token is null)
      or (user_id is null and guest_token is not null)
    )
);

comment on table public.carts is
  'Authenticated carts use user_id. Guest carts use guest_token for schema '
  'support only — Flutter MVP keeps guests local; do not expose insecure '
  'anon RLS by guest_token alone.';

create unique index carts_one_active_per_user_idx
  on public.carts (user_id)
  where status = 'active' and user_id is not null;

create index carts_status_idx on public.carts (status);
create index carts_guest_token_idx on public.carts (guest_token);

create trigger carts_set_updated_at
before update on public.carts
for each row
execute function public.set_updated_at();

create table public.cart_items (
  id uuid primary key default gen_random_uuid(),
  cart_id uuid not null references public.carts (id) on delete cascade,
  variant_id uuid not null references public.product_variants (id) on delete restrict,
  quantity integer not null,
  unit_price_snapshot numeric(14, 2),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint cart_items_quantity_check check (quantity > 0),
  constraint cart_items_price_snapshot_check
    check (unit_price_snapshot is null or unit_price_snapshot >= 0),
  constraint cart_items_unique_variant unique (cart_id, variant_id)
);

comment on table public.cart_items is
  'Cart lines. unit_price_snapshot is display-only; checkout re-fetches price.';

create index cart_items_cart_id_idx on public.cart_items (cart_id);
create index cart_items_variant_id_idx on public.cart_items (variant_id);

create trigger cart_items_set_updated_at
before update on public.cart_items
for each row
execute function public.set_updated_at();
