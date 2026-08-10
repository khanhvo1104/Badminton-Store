-- Safe catalog view + public stock RPC (no cost_price / reserved qty).

create or replace view public.product_catalog
with (security_invoker = true)
as
select
  p.id,
  p.name,
  p.slug,
  p.short_description,
  p.is_featured,
  p.published_at,
  c.id as category_id,
  c.name as category_name,
  c.slug as category_slug,
  b.id as brand_id,
  b.name as brand_name,
  b.slug as brand_slug,
  (
    select pi.storage_path
    from public.product_images pi
    where pi.product_id = p.id
      and pi.variant_id is null
      and pi.is_primary = true
    order by pi.sort_order
    limit 1
  ) as primary_image_path,
  (
    select min(pv.price)
    from public.product_variants pv
    where pv.product_id = p.id
      and pv.is_active = true
  ) as min_price,
  (
    select max(pv.price)
    from public.product_variants pv
    where pv.product_id = p.id
      and pv.is_active = true
  ) as max_price,
  (
    select min(pv.compare_at_price)
    from public.product_variants pv
    where pv.product_id = p.id
      and pv.is_active = true
      and pv.compare_at_price is not null
  ) as min_compare_at_price,
  (
    select count(*)::integer
    from public.product_variants pv
    where pv.product_id = p.id
      and pv.is_active = true
  ) as active_variant_count,
  exists (
    select 1
    from public.product_variants pv
    join public.inventory i on i.variant_id = pv.id
    where pv.product_id = p.id
      and pv.is_active = true
      and (i.quantity_on_hand - i.quantity_reserved > 0 or i.allow_backorder)
  ) as has_stock
from public.products p
join public.categories c on c.id = p.category_id
left join public.brands b on b.id = p.brand_id
where p.status = 'active'
  and c.is_active = true
  and (b.id is null or b.is_active = true);

comment on view public.product_catalog is
  'Public catalog projection. security_invoker=true. No cost_price. '
  'Flutter should query this view for listing screens.';

grant select on public.product_catalog to anon, authenticated;

-- Public stock availability without exposing reserved/reorder internals.
create or replace function public.get_variant_availability(p_variant_id uuid)
returns table (
  variant_id uuid,
  available_quantity integer,
  is_in_stock boolean,
  allow_backorder boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    i.variant_id,
    greatest(i.quantity_on_hand - i.quantity_reserved, 0)::integer
      as available_quantity,
    (i.quantity_on_hand - i.quantity_reserved > 0 or i.allow_backorder)
      as is_in_stock,
    i.allow_backorder
  from public.inventory i
  join public.product_variants pv on pv.id = i.variant_id
  join public.products p on p.id = pv.product_id
  where i.variant_id = p_variant_id
    and pv.is_active = true
    and p.status = 'active';
$$;

comment on function public.get_variant_availability(uuid) is
  'Safe public stock fields for an active variant. SECURITY DEFINER; '
  'does not return quantity_reserved or reorder_level.';

revoke all on function public.get_variant_availability(uuid) from public;
grant execute on function public.get_variant_availability(uuid)
  to anon, authenticated, service_role;

-- Simple product search RPC (name/keywords + brand/category names).
create or replace function public.search_products(p_query text, p_limit integer default 20)
returns setof public.product_catalog
language sql
stable
security invoker
set search_path = public
as $$
  select pc.*
  from public.product_catalog pc
  join public.products p on p.id = pc.id
  where p.search_vector @@ plainto_tsquery('simple', coalesce(p_query, ''))
     or pc.name ilike '%' || coalesce(p_query, '') || '%'
     or coalesce(pc.brand_name, '') ilike '%' || coalesce(p_query, '') || '%'
     or coalesce(pc.category_name, '') ilike '%' || coalesce(p_query, '') || '%'
  order by pc.is_featured desc, pc.published_at desc nulls last
  limit greatest(1, least(coalesce(p_limit, 20), 100));
$$;

comment on function public.search_products(text, integer) is
  'MVP catalog search via tsvector + ilike. SECURITY INVOKER.';

revoke all on function public.search_products(text, integer) from public;
grant execute on function public.search_products(text, integer)
  to anon, authenticated, service_role;
