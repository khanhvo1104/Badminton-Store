-- TASK-038 review: atomic CMS product-image insert and metadata update.
--
-- SECURITY INVOKER so existing product_images RLS and grants still apply.
-- SECURITY DEFINER is not used: authenticated staff/admin already have
-- INSERT/UPDATE/SELECT on public.product_images.
--
-- insert_cms_product_image creates the row and optional primary assignment in
-- one transaction so a later primary RPC cannot persist a row after reporting
-- failure.
--
-- update_cms_product_image moves variant scope and maintains old/destination
-- primaries in one locked transaction so a partial move cannot stick.
--
-- Both functions take the same advisory locks as set_cms_product_image_primary
-- then reorder_cms_product_images (that order) to serialize with those RPCs.
--
-- Does not alter tables, RLS policies, Storage policies, or column grants.

create or replace function public.insert_cms_product_image(
  p_product_id uuid,
  p_storage_path text,
  p_alt_text text,
  p_variant_id uuid,
  p_set_primary boolean
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
  v_variant_product uuid;
  v_path text;
  v_alt text;
  v_count integer;
  v_sort integer;
  v_image_id uuid;
  v_assign_primary boolean;
begin
  if not public.is_staff_or_admin() then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  if p_product_id is null
     or p_storage_path is null
     or p_set_primary is null
  then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_path := pg_catalog.btrim(p_storage_path);
  if v_path is distinct from pg_catalog.lower(v_path)
     or pg_catalog.char_length(v_path) < 1
     or pg_catalog.char_length(v_path) > 500
     or v_path !~ (
       '^product-images/'
       || p_product_id::text
       || '/[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|jpeg|png|webp|gif)$'
     )
  then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_alt_text is null then
    v_alt := null;
  else
    v_alt := pg_catalog.btrim(p_alt_text);
    if pg_catalog.char_length(v_alt) = 0 then
      v_alt := null;
    elsif pg_catalog.char_length(v_alt) > 200 then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
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

  if p_variant_id is not null then
    select variant_row.product_id
    into v_variant_product
    from public.product_variants as variant_row
    where variant_row.id = p_variant_id;

    if v_variant_product is distinct from p_product_id then
      raise exception 'invalid variant'
        using errcode = '22023';
    end if;
  end if;

  select pg_catalog.count(*)::integer
  into v_count
  from public.product_images as image_row
  where image_row.product_id = p_product_id;

  if v_count >= 20 then
    raise exception 'image limit exceeded'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.product_images as image_row
    where image_row.storage_path = v_path
  ) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  select coalesce(pg_catalog.max(image_row.sort_order), -1)::integer + 1
  into v_sort
  from public.product_images as image_row
  where image_row.product_id = p_product_id;

  insert into public.product_images (
    product_id,
    variant_id,
    storage_path,
    alt_text,
    sort_order,
    is_primary
  ) values (
    p_product_id,
    p_variant_id,
    v_path,
    v_alt,
    v_sort,
    false
  )
  returning id into v_image_id;

  v_assign_primary := p_set_primary
    or not exists (
      select 1
      from public.product_images as image_row
      where image_row.product_id = p_product_id
        and image_row.id is distinct from v_image_id
        and image_row.variant_id is not distinct from p_variant_id
        and image_row.is_primary = true
    );

  if v_assign_primary then
    if p_variant_id is null then
      update public.product_images as image_row
      set is_primary = false
      where image_row.product_id = p_product_id
        and image_row.variant_id is null
        and image_row.is_primary = true
        and image_row.id is distinct from v_image_id;
    else
      update public.product_images as image_row
      set is_primary = false
      where image_row.product_id = p_product_id
        and image_row.variant_id = p_variant_id
        and image_row.is_primary = true
        and image_row.id is distinct from v_image_id;
    end if;

    update public.product_images as image_row
    set is_primary = true
    where image_row.id = v_image_id
      and image_row.product_id = p_product_id
    returning image_row.id into v_image_id;

    if v_image_id is null then
      raise exception 'not found'
        using errcode = 'P0002';
    end if;
  end if;

  return query select v_image_id as image_id;
end;
$$;

comment on function public.insert_cms_product_image(uuid, text, text, uuid, boolean) is
  'CMS product image insert. SECURITY INVOKER, VOLATILE, empty search_path. '
  'Authorizes via is_staff_or_admin(). Locks the product, validates a '
  'product-scoped raster storage_path, inserts is_primary=false, then assigns '
  'primary in the same transaction when requested or when the scope has none. '
  'Returns only image_id. EXECUTE granted to authenticated and service_role only.';

revoke all on function public.insert_cms_product_image(uuid, text, text, uuid, boolean)
  from public;
revoke all on function public.insert_cms_product_image(uuid, text, text, uuid, boolean)
  from anon;
revoke all on function public.insert_cms_product_image(uuid, text, text, uuid, boolean)
  from authenticated;
revoke all on function public.insert_cms_product_image(uuid, text, text, uuid, boolean)
  from service_role;

grant execute on function public.insert_cms_product_image(uuid, text, text, uuid, boolean)
  to authenticated, service_role;

create or replace function public.update_cms_product_image(
  p_product_id uuid,
  p_image_id uuid,
  p_alt_text text,
  p_variant_id uuid,
  p_sort_order integer
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
  v_image_id uuid;
  v_image_product uuid;
  v_old_variant uuid;
  v_was_primary boolean;
  v_variant_product uuid;
  v_alt text;
  v_next uuid;
  v_changed boolean;
begin
  if not public.is_staff_or_admin() then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  if p_product_id is null
     or p_image_id is null
     or p_sort_order is null
  then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_sort_order < -1000000 or p_sort_order > 1000000 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_alt_text is null then
    v_alt := null;
  else
    v_alt := pg_catalog.btrim(p_alt_text);
    if pg_catalog.char_length(v_alt) = 0 then
      v_alt := null;
    elsif pg_catalog.char_length(v_alt) > 200 then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
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
  perform pg_catalog.pg_advisory_xact_lock(
    (
      'x' || pg_catalog.substr(
        pg_catalog.md5('cms-product-image-reorder:' || p_product_id::text),
        1,
        16
      )
    )::bit(64)::bigint
  );

  if not exists (
    select 1
    from public.products as product_row
    where product_row.id = p_product_id
  ) then
    raise exception 'not found'
      using errcode = 'P0002';
  end if;

  select image_row.id, image_row.product_id, image_row.variant_id, image_row.is_primary
  into v_image_id, v_image_product, v_old_variant, v_was_primary
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

  if p_variant_id is not null then
    select variant_row.product_id
    into v_variant_product
    from public.product_variants as variant_row
    where variant_row.id = p_variant_id;

    if v_variant_product is distinct from p_product_id then
      raise exception 'invalid variant'
        using errcode = '22023';
    end if;
  end if;

  v_changed := v_old_variant is distinct from p_variant_id;

  update public.product_images as image_row
  set
    alt_text = v_alt,
    variant_id = p_variant_id,
    sort_order = p_sort_order,
    is_primary = case
      when v_changed then false
      else image_row.is_primary
    end
  where image_row.id = p_image_id
    and image_row.product_id = p_product_id
  returning image_row.id into v_image_id;

  if v_image_id is null then
    raise exception 'not found'
      using errcode = 'P0002';
  end if;

  if v_changed and v_was_primary then
    select image_row.id
    into v_next
    from public.product_images as image_row
    where image_row.product_id = p_product_id
      and image_row.id is distinct from p_image_id
      and image_row.variant_id is not distinct from v_old_variant
    order by image_row.sort_order asc, image_row.id asc
    limit 1;

    if v_next is not null then
      if v_old_variant is null then
        update public.product_images as image_row
        set is_primary = false
        where image_row.product_id = p_product_id
          and image_row.variant_id is null
          and image_row.is_primary = true
          and image_row.id is distinct from v_next;
      else
        update public.product_images as image_row
        set is_primary = false
        where image_row.product_id = p_product_id
          and image_row.variant_id = v_old_variant
          and image_row.is_primary = true
          and image_row.id is distinct from v_next;
      end if;

      update public.product_images as image_row
      set is_primary = true
      where image_row.id = v_next
        and image_row.product_id = p_product_id;
    end if;
  end if;

  if v_changed
     and not exists (
       select 1
       from public.product_images as image_row
       where image_row.product_id = p_product_id
         and image_row.id is distinct from p_image_id
         and image_row.variant_id is not distinct from p_variant_id
         and image_row.is_primary = true
     )
  then
    if p_variant_id is null then
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
        and image_row.variant_id = p_variant_id
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
  end if;

  return query select p_image_id as image_id;
end;
$$;

comment on function public.update_cms_product_image(uuid, uuid, text, uuid, integer) is
  'CMS product image metadata update. SECURITY INVOKER, VOLATILE, empty '
  'search_path. Authorizes via is_staff_or_admin(). Locks the product, verifies '
  'the image belongs to p_product_id, updates alt/variant/sort, and maintains '
  'exactly one primary in the old and destination scopes in one transaction. '
  'Returns only image_id. EXECUTE granted to authenticated and service_role only.';

revoke all on function public.update_cms_product_image(uuid, uuid, text, uuid, integer)
  from public;
revoke all on function public.update_cms_product_image(uuid, uuid, text, uuid, integer)
  from anon;
revoke all on function public.update_cms_product_image(uuid, uuid, text, uuid, integer)
  from authenticated;
revoke all on function public.update_cms_product_image(uuid, uuid, text, uuid, integer)
  from service_role;

grant execute on function public.update_cms_product_image(uuid, uuid, text, uuid, integer)
  to authenticated, service_role;
