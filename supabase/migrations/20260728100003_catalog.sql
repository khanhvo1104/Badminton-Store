-- Catalog: categories, brands, products (no variant price/stock here).

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.categories (id) on delete set null,
  name text not null,
  slug text not null,
  description text,
  image_path text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint categories_slug_unique unique (slug),
  constraint categories_name_check
    check (char_length(trim(name)) between 1 and 120),
  constraint categories_slug_check
    check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  constraint categories_no_self_parent_check
    check (parent_id is distinct from id)
);

comment on table public.categories is
  'Product taxonomy. Supports optional nesting via parent_id.';

create index categories_parent_id_idx on public.categories (parent_id);
create index categories_is_active_idx on public.categories (is_active);
create index categories_sort_order_idx on public.categories (sort_order);

create trigger categories_set_updated_at
before update on public.categories
for each row
execute function public.set_updated_at();

create table public.brands (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null,
  description text,
  logo_path text,
  website_url text,
  country_of_origin text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint brands_slug_unique unique (slug),
  constraint brands_name_check
    check (char_length(trim(name)) between 1 and 120),
  constraint brands_slug_check
    check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

comment on table public.brands is
  'Brand directory for catalog filtering. Sample data is demonstrative only.';

create index brands_is_active_idx on public.brands (is_active);
create index brands_sort_order_idx on public.brands (sort_order);

create trigger brands_set_updated_at
before update on public.brands
for each row
execute function public.set_updated_at();

create table public.products (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories (id) on delete restrict,
  brand_id uuid references public.brands (id) on delete set null,
  name text not null,
  slug text not null,
  short_description text,
  description text,
  specifications jsonb not null default '{}'::jsonb,
  search_keywords text,
  status text not null default 'draft',
  is_featured boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint products_slug_unique unique (slug),
  constraint products_status_check
    check (status in ('draft', 'active', 'inactive', 'archived')),
  constraint products_name_check
    check (char_length(trim(name)) between 1 and 200),
  constraint products_slug_check
    check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  constraint products_active_published_check
    check (status <> 'active' or published_at is not null)
);

comment on table public.products is
  'Catalog parent. Selling price and stock live on variants/inventory.';
comment on column public.products.specifications is
  'Category-dependent tech attributes (balance, stiffness, materials, etc.).';
comment on column public.products.status is
  'draft | active | inactive | archived. Public reads active only.';

create index products_category_id_idx on public.products (category_id);
create index products_brand_id_idx on public.products (brand_id);
create index products_status_idx on public.products (status);
create index products_is_featured_idx on public.products (is_featured);
create index products_published_at_idx on public.products (published_at desc);
create index products_slug_idx on public.products (slug);

-- MVP search: generated tsvector over name + keywords (brand/category joined in views/RPC).
alter table public.products
  add column search_vector tsvector
  generated always as (
    setweight(to_tsvector('simple', coalesce(name, '')), 'A')
    || setweight(to_tsvector('simple', coalesce(search_keywords, '')), 'B')
  ) stored;

create index products_search_vector_idx on public.products using gin (search_vector);

create trigger products_set_updated_at
before update on public.products
for each row
execute function public.set_updated_at();
