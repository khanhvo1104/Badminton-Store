-- TASK-038: CMS product media primary switch and bounded reorder RPCs.
--
-- SECURITY INVOKER so existing product_images RLS and grants still apply.
-- SECURITY DEFINER is not used: authenticated staff/admin already have
-- UPDATE (and SELECT) on public.product_images. These functions exist to
-- serialize unique-index primary switches and bounded reorders in one
-- transaction.
--
-- Unique indexes on product_images are checked per row, so setting a new
-- primary requires unsetting the previous primary first. Concurrent CMS
-- updates would race without an advisory lock and a two-step update.
--
-- Does not alter tables, RLS policies, Storage policies, or column grants.

create or replace function public.set_cms_product_image_primary(
  p_product_id uuid,
  p_image_id uuid
)
returns table (
  image_id uuid
)
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_product_id uuid;
  v_image_id uuid;
  v_image_product uuid;
  v_variant_id uuid;
begin
  if not public.is_staff_or_admin() then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  if p_product_id is null or p_image_id is null then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    (
      'x' || pg_catalog.substr(
        pg_catalog.md5('cms-product-image-primary:' || p_product_id::text),
        1,
        16
      )
    )::bit(64)::bigint
  );

  select product_row.id
  into v_product_id
  from public.products as product_row
  where product_row.id = p_product_id;

  if v_product_id is null then
    raise exception 'not found'
      using errcode = 'P0002';
  end if;

  select image_row.id, image_row.product_id, image_row.variant_id
  into v_image_id, v_image_product, v_variant_id
  from public.product_images as image_row
  where image_row.id = p_image_id;

  if v_image_id is null then
    raise exception 'not found'
      using errcode = 'P0002';
  end if;

  if v_image_product is distinct from p_product_id then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if v_variant_id is null then
    update public.product_images as image_row
    set is_primary = false
    where image_row.product_id = p_product_id
      and image_row.variant_id is null
      and image_row.is_primary = true
      and image_row.id is distinct from p_image_id;
  else
    update public.product_images as image_row
    set is_primary = false
    where image_row.product_id = p_product_id
      and image_row.variant_id = v_variant_id
      and image_row.is_primary = true
      and image_row.id is distinct from p_image_id;
  end if;

  update public.product_images as image_row
  set is_primary = true
  where image_row.id = p_image_id
    and image_row.product_id = p_product_id
  returning image_row.id into v_image_id;

  if v_image_id is null then
    raise exception 'not found'
      using errcode = 'P0002';
  end if;

  return query select v_image_id as image_id;
end;
$$;

comment on function public.set_cms_product_image_primary(uuid, uuid) is
  'CMS product image primary switch. SECURITY INVOKER, VOLATILE, empty '
  'search_path. Authorizes via is_staff_or_admin(). Locks the product, verifies '
  'the image belongs to p_product_id, unsets other primaries in the same '
  'general or variant scope, then sets the target. Returns only image_id. '
  'EXECUTE granted to authenticated and service_role only.';

revoke all on function public.set_cms_product_image_primary(uuid, uuid)
  from public;
revoke all on function public.set_cms_product_image_primary(uuid, uuid)
  from anon;
revoke all on function public.set_cms_product_image_primary(uuid, uuid)
  from authenticated;
revoke all on function public.set_cms_product_image_primary(uuid, uuid)
  from service_role;

grant execute on function public.set_cms_product_image_primary(uuid, uuid)
  to authenticated, service_role;

create or replace function public.reorder_cms_product_images(
  p_product_id uuid,
  p_image_ids uuid[]
)
returns table (
  product_id uuid
)
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_product_id uuid;
  v_len integer;
  v_distinct integer;
  v_existing integer;
  v_updated integer;
begin
  if not public.is_staff_or_admin() then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  if p_product_id is null or p_image_ids is null then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_len := coalesce(pg_catalog.cardinality(p_image_ids), 0);
  if v_len < 1 or v_len > 20 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from pg_catalog.unnest(p_image_ids) as requested(image_id)
    where requested.image_id is null
  ) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  select pg_catalog.count(distinct requested.image_id)::integer
  into v_distinct
  from pg_catalog.unnest(p_image_ids) as requested(image_id);

  if v_distinct is distinct from v_len then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    (
      'x' || pg_catalog.substr(
        pg_catalog.md5('cms-product-image-reorder:' || p_product_id::text),
        1,
        16
      )
    )::bit(64)::bigint
  );

  select product_row.id
  into v_product_id
  from public.products as product_row
  where product_row.id = p_product_id;

  if v_product_id is null then
    raise exception 'not found'
      using errcode = 'P0002';
  end if;

  select pg_catalog.count(*)::integer
  into v_existing
  from public.product_images as image_row
  where image_row.product_id = p_product_id;

  if v_existing is distinct from v_len then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from pg_catalog.unnest(p_image_ids) as requested(image_id)
    left join public.product_images as image_row
      on image_row.id = requested.image_id
     and image_row.product_id = p_product_id
    where image_row.id is null
  ) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  update public.product_images as image_row
  set sort_order = requested.sort_order
  from (
    select
      u.image_id,
      (u.ordinality - 1)::integer as sort_order
    from pg_catalog.unnest(p_image_ids) with ordinality as u(image_id, ordinality)
  ) as requested
  where image_row.id = requested.image_id
    and image_row.product_id = p_product_id;

  get diagnostics v_updated = row_count;
  if v_updated is distinct from v_len then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  return query select p_product_id as product_id;
end;
$$;

comment on function public.reorder_cms_product_images(uuid, uuid[]) is
  'CMS product image reorder. SECURITY INVOKER, VOLATILE, empty search_path. '
  'Authorizes via is_staff_or_admin(). Requires a complete, duplicate-free, '
  'product-scoped id list of length 1..20. Locks the product and writes '
  'sort_order from array order. Returns only product_id. EXECUTE granted to '
  'authenticated and service_role only.';

revoke all on function public.reorder_cms_product_images(uuid, uuid[])
  from public;
revoke all on function public.reorder_cms_product_images(uuid, uuid[])
  from anon;
revoke all on function public.reorder_cms_product_images(uuid, uuid[])
  from authenticated;
revoke all on function public.reorder_cms_product_images(uuid, uuid[])
  from service_role;

grant execute on function public.reorder_cms_product_images(uuid, uuid[])
  to authenticated, service_role;
