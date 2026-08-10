-- Orders, order items, status history. Checkout inserts via trusted RPC later.

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null,
  user_id uuid not null references public.profiles (id) on delete restrict,
  status text not null default 'pending',
  payment_method text not null default 'cod',
  payment_status text not null default 'unpaid',
  currency_code text not null default 'VND',
  subtotal numeric(14, 2) not null,
  discount_total numeric(14, 2) not null default 0,
  shipping_fee numeric(14, 2) not null default 0,
  grand_total numeric(14, 2) not null,
  customer_note text,
  recipient_name text not null,
  recipient_phone text not null,
  shipping_address jsonb not null,
  placed_at timestamptz not null default timezone('utc', now()),
  cancelled_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint orders_order_number_unique unique (order_number),
  constraint orders_status_check
    check (
      status in (
        'pending',
        'confirmed',
        'preparing',
        'shipping',
        'delivered',
        'cancelled',
        'returned'
      )
    ),
  constraint orders_payment_method_check
    check (payment_method in ('cod')),
  constraint orders_payment_status_check
    check (
      payment_status in ('unpaid', 'pending', 'paid', 'failed', 'refunded')
    ),
  constraint orders_currency_check check (char_length(currency_code) = 3),
  constraint orders_subtotal_check check (subtotal >= 0),
  constraint orders_discount_check check (discount_total >= 0),
  constraint orders_shipping_check check (shipping_fee >= 0),
  constraint orders_grand_total_check check (grand_total >= 0),
  constraint orders_discount_lte_subtotal_check
    check (discount_total <= subtotal),
  constraint orders_grand_total_math_check
    check (grand_total = subtotal - discount_total + shipping_fee),
  constraint orders_recipient_name_check
    check (char_length(trim(recipient_name)) between 1 and 120),
  constraint orders_recipient_phone_check
    check (char_length(trim(recipient_phone)) between 8 and 20)
);

comment on table public.orders is
  'Customer orders. Totals and status are server-trusted; Flutter must not '
  'insert trusted totals directly. shipping_address is an immutable snapshot.';
comment on column public.orders.shipping_address is
  'JSON snapshot of delivery address at placement time.';

create index orders_user_id_idx on public.orders (user_id);
create index orders_status_idx on public.orders (status);
create index orders_payment_status_idx on public.orders (payment_status);
create index orders_placed_at_idx on public.orders (placed_at desc);

create trigger orders_set_updated_at
before update on public.orders
for each row
execute function public.set_updated_at();

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  product_id uuid references public.products (id) on delete set null,
  variant_id uuid references public.product_variants (id) on delete set null,
  product_name text not null,
  variant_name text,
  sku text not null,
  image_path text,
  unit_price numeric(14, 2) not null,
  quantity integer not null,
  line_total numeric(14, 2) not null,
  product_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  constraint order_items_quantity_check check (quantity > 0),
  constraint order_items_unit_price_check check (unit_price >= 0),
  constraint order_items_line_total_check
    check (line_total = unit_price * quantity)
);

comment on table public.order_items is
  'Immutable line snapshots. Catalog FKs are nullable so history survives '
  'product archival/deletion.';

create index order_items_order_id_idx on public.order_items (order_id);
create index order_items_product_id_idx on public.order_items (product_id);
create index order_items_variant_id_idx on public.order_items (variant_id);

create table public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  from_status text,
  to_status text not null,
  changed_by uuid references public.profiles (id) on delete set null,
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint order_status_history_to_status_check
    check (
      to_status in (
        'pending',
        'confirmed',
        'preparing',
        'shipping',
        'delivered',
        'cancelled',
        'returned'
      )
    )
);

comment on table public.order_status_history is
  'Append-only status transitions. Written by trigger / staff / trusted RPC.';

create index order_status_history_order_id_idx
  on public.order_status_history (order_id);
create index order_status_history_created_at_idx
  on public.order_status_history (created_at desc);
