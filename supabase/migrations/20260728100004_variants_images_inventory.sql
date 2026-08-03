-- Variants, images, inventory.

create table public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete restrict,
  sku text not null,
  name text,
  color_name text,
  color_hex text,
  racket_weight_class text,
  grip_size text,
  shoe_size text,
  clothing_size text,
  unit text not null default 'item',
  price numeric(14, 2) not null,
  compare_at_price numeric(14, 2),
  cost_price numeric(14, 2),
  barcode text,
  attributes jsonb not null default '{}'::jsonb,
  is_default boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint product_variants_sku_unique unique (sku),
  constraint product_variants_barcode_unique unique (barcode),
  constraint product_variants_price_check check (price >= 0),
  constraint product_variants_cost_price_check
    check (cost_price is null or cost_price >= 0),
  constraint product_variants_compare_at_check
    check (compare_at_price is null or compare_at_price >= price),
  constraint product_variants_color_hex_check
    check (color_hex is null or color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  constraint product_variants_unit_check
    check (char_length(trim(unit)) between 1 and 40)
);

comment on table public.product_variants is
  'Sellable SKUs. Price lives here; stock lives in inventory.';
comment on column public.product_variants.cost_price is
  'Internal cost. Never expose via public catalog views.';

create index product_variants_product_id_idx
  on public.product_variants (product_id);
create index product_variants_sku_idx on public.product_variants (sku);
create index product_variants_is_active_idx
  on public.product_variants (is_active);
create index product_variants_price_idx on public.product_variants (price);
create index product_variants_racket_weight_idx
  on public.product_variants (racket_weight_class);
create index product_variants_grip_size_idx
  on public.product_variants (grip_size);
create index product_variants_shoe_size_idx
  on public.product_variants (shoe_size);
create index product_variants_clothing_size_idx
  on public.product_variants (clothing_size);

create unique index product_variants_one_default_per_product_idx
  on public.product_variants (product_id)
  where is_default = true;

create trigger product_variants_set_updated_at
before update on public.product_variants
for each row
execute function public.set_updated_at();

create table public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  variant_id uuid references public.product_variants (id) on delete cascade,
  storage_path text not null,
  alt_text text,
  sort_order integer not null default 0,
  is_primary boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint product_images_path_check
    check (char_length(trim(storage_path)) between 1 and 500)
);

comment on table public.product_images is
  'Storage paths for product/variant media. One general primary image per product.';
comment on column public.product_images.is_primary is
  'Primary general product image when variant_id is null. '
  'Variant-specific primaries are scoped by variant_id.';

create index product_images_product_id_idx on public.product_images (product_id);
create index product_images_variant_id_idx on public.product_images (variant_id);
create index product_images_sort_order_idx on public.product_images (sort_order);

-- One primary general image per product (variant_id is null).
create unique index product_images_one_primary_general_idx
  on public.product_images (product_id)
  where is_primary = true and variant_id is null;

-- One primary image per variant when variant_id is set.
create unique index product_images_one_primary_per_variant_idx
  on public.product_images (variant_id)
  where is_primary = true and variant_id is not null;

create trigger product_images_set_updated_at
before update on public.product_images
for each row
execute function public.set_updated_at();

-- Ensure variant images belong to the same product.
create or replace function public.validate_product_image_variant()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_product_id uuid;
begin
  if new.variant_id is null then
    return new;
  end if;

  select pv.product_id into v_product_id
  from public.product_variants pv
  where pv.id = new.variant_id;

  if v_product_id is null then
    raise exception 'product_images.variant_id % does not exist', new.variant_id;
  end if;

  if v_product_id <> new.product_id then
    raise exception
      'product_images.variant_id must belong to product_id %', new.product_id;
  end if;

  return new;
end;
$$;

comment on function public.validate_product_image_variant() is
  'Ensures variant_id belongs to the same product as product_id.';

create trigger product_images_validate_variant
before insert or update on public.product_images
for each row
execute function public.validate_product_image_variant();

create table public.inventory (
  variant_id uuid primary key
    references public.product_variants (id) on delete cascade,
  quantity_on_hand integer not null default 0,
  quantity_reserved integer not null default 0,
  reorder_level integer not null default 0,
  allow_backorder boolean not null default false,
  updated_at timestamptz not null default timezone('utc', now()),
  constraint inventory_on_hand_check check (quantity_on_hand >= 0),
  constraint inventory_reserved_check check (quantity_reserved >= 0),
  constraint inventory_reorder_check check (reorder_level >= 0),
  constraint inventory_reserved_lte_on_hand_check
    check (allow_backorder or quantity_reserved <= quantity_on_hand)
);

comment on table public.inventory is
  'Per-variant stock. Customers never write this table. '
  'Checkout must reserve stock atomically in a trusted RPC.';

create trigger inventory_set_updated_at
before update on public.inventory
for each row
execute function public.set_updated_at();

-- Safe public stock projection (no reserved/reorder internals).
create or replace view public.inventory_availability
with (security_invoker = true)
as
select
  i.variant_id,
  greatest(i.quantity_on_hand - i.quantity_reserved, 0) as available_quantity,
  (i.quantity_on_hand - i.quantity_reserved > 0 or i.allow_backorder) as is_in_stock,
  i.allow_backorder
from public.inventory i;

comment on view public.inventory_availability is
  'Public-safe stock fields. security_invoker=true so underlying RLS applies.';
