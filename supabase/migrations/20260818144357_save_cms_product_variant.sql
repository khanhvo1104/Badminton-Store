-- TASK-036: staff/admin CMS variant create/update RPC.
--
-- SECURITY INVOKER so existing RLS and column grants still apply. Callers
-- cannot SELECT cost_price or barcode; this function writes those columns
-- without reading them. Barcode and cost use an explicit unchanged/clear/set
-- contract so an edit never silently clears a value the caller cannot read.
--
-- Does not alter tables, RLS policies, Storage policies, or column grants.

create or replace function public.save_cms_product_variant(
  p_product_id uuid,
  p_variant_id uuid,
  p_sku text,
  p_name text,
  p_color_name text,
  p_color_hex text,
  p_racket_weight_class text,
  p_grip_size text,
  p_shoe_size text,
  p_clothing_size text,
  p_unit text,
  p_price numeric,
  p_compare_at_price numeric,
  p_cost_mode text,
  p_cost_price numeric,
  p_barcode_mode text,
  p_barcode text,
  p_attributes jsonb,
  p_is_default boolean,
  p_is_active boolean,
  p_sort_order integer
)
returns table (
  variant_id uuid
)
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_product_id uuid;
  v_existing_id uuid;
  v_existing_default boolean;
  v_existing_product uuid;
  v_variant_count integer;
  v_sku text;
  v_name text;
  v_color_name text;
  v_color_hex text;
  v_racket_weight_class text;
  v_grip_size text;
  v_shoe_size text;
  v_clothing_size text;
  v_unit text;
  v_barcode text;
  v_is_default boolean;
  v_saved_id uuid;
  v_items jsonb[];
  v_depths integer[];
  v_node jsonb;
  v_depth integer;
  v_key text;
  v_val jsonb;
  v_i integer;
  v_key_count integer := 0;
begin
  if not public.is_staff_or_admin() then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  if p_product_id is null
     or p_is_default is null
     or p_is_active is null
     or p_sort_order is null
     or p_price is null
     or p_cost_mode is null
     or p_barcode_mode is null
     or p_unit is null
     or p_sku is null
     or p_attributes is null
  then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_cost_mode not in ('unchanged', 'clear', 'set')
     or p_barcode_mode not in ('unchanged', 'clear', 'set')
  then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_cost_mode = 'set' then
    if p_cost_price is null
       or p_cost_price < 0
       or p_cost_price <> pg_catalog.round(p_cost_price, 2)
       or p_cost_price > 999999999999.99
    then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
  elsif p_cost_price is not null then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_barcode_mode = 'set' then
    v_barcode := pg_catalog.btrim(coalesce(p_barcode, ''));
    v_barcode := pg_catalog.regexp_replace(v_barcode, '[[:space:]]+', ' ', 'g');
    if v_barcode = ''
       or pg_catalog.char_length(v_barcode) > 80
    then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
  elsif p_barcode is not null and pg_catalog.btrim(p_barcode) <> '' then
    raise exception 'invalid request'
      using errcode = '22023';
  else
    v_barcode := null;
  end if;

  if p_price < 0
     or p_price <> pg_catalog.round(p_price, 2)
     or p_price > 999999999999.99
  then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_compare_at_price is not null then
    if p_compare_at_price < 0
       or p_compare_at_price <> pg_catalog.round(p_compare_at_price, 2)
       or p_compare_at_price > 999999999999.99
       or p_compare_at_price < p_price
    then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
  end if;

  if p_sort_order < -1000000 or p_sort_order > 1000000 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  -- SKU rule: trim, collapse internal whitespace to a single space, preserve
  -- case, require 1..80 characters. Applied here and in the CMS.
  v_sku := pg_catalog.btrim(p_sku);
  v_sku := pg_catalog.regexp_replace(v_sku, '[[:space:]]+', ' ', 'g');
  if v_sku = '' or pg_catalog.char_length(v_sku) > 80 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_name := nullif(pg_catalog.btrim(coalesce(p_name, '')), '');
  if v_name is not null and pg_catalog.char_length(v_name) > 200 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_color_name := nullif(pg_catalog.btrim(coalesce(p_color_name, '')), '');
  if v_color_name is not null and pg_catalog.char_length(v_color_name) > 80 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_color_hex := nullif(pg_catalog.btrim(coalesce(p_color_hex, '')), '');
  if v_color_hex is not null
     and v_color_hex !~ '^#[0-9A-Fa-f]{6}$'
  then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_racket_weight_class :=
    nullif(pg_catalog.btrim(coalesce(p_racket_weight_class, '')), '');
  v_grip_size := nullif(pg_catalog.btrim(coalesce(p_grip_size, '')), '');
  v_shoe_size := nullif(pg_catalog.btrim(coalesce(p_shoe_size, '')), '');
  v_clothing_size := nullif(pg_catalog.btrim(coalesce(p_clothing_size, '')), '');

  if (v_racket_weight_class is not null
      and pg_catalog.char_length(v_racket_weight_class) > 40)
     or (v_grip_size is not null and pg_catalog.char_length(v_grip_size) > 40)
     or (v_shoe_size is not null and pg_catalog.char_length(v_shoe_size) > 40)
     or (v_clothing_size is not null
         and pg_catalog.char_length(v_clothing_size) > 40)
  then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_unit := pg_catalog.btrim(p_unit);
  if v_unit = '' or pg_catalog.char_length(v_unit) > 40 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if pg_catalog.jsonb_typeof(p_attributes) is distinct from 'object' then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if pg_catalog.length(p_attributes::text) > 8192 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_items := array[p_attributes];
  v_depths := array[1];
  v_i := 1;
  while v_i <= pg_catalog.array_length(v_items, 1) loop
    v_node := v_items[v_i];
    v_depth := v_depths[v_i];
    v_i := v_i + 1;

    if pg_catalog.jsonb_typeof(v_node) is distinct from 'object' then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;

    if v_depth > 3 then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;

    for v_key, v_val in
      select e.key, e.value
      from pg_catalog.jsonb_each(v_node) as e(key, value)
    loop
      if v_key = ''
         or pg_catalog.char_length(v_key) > 80
         or v_key in ('__proto__', 'prototype', 'constructor')
      then
        raise exception 'invalid request'
          using errcode = '22023';
      end if;

      v_key_count := v_key_count + 1;
      if v_key_count > 50 then
        raise exception 'invalid request'
          using errcode = '22023';
      end if;

      if pg_catalog.jsonb_typeof(v_val) = 'array' then
        raise exception 'invalid request'
          using errcode = '22023';
      elsif pg_catalog.jsonb_typeof(v_val) = 'string' then
        if pg_catalog.char_length(v_val #>> '{}') > 500 then
          raise exception 'invalid request'
            using errcode = '22023';
        end if;
      elsif pg_catalog.jsonb_typeof(v_val) = 'number' then
        null;
      elsif pg_catalog.jsonb_typeof(v_val) = 'boolean' then
        null;
      elsif pg_catalog.jsonb_typeof(v_val) = 'null' then
        null;
      elsif pg_catalog.jsonb_typeof(v_val) = 'object' then
        v_items := v_items || v_val;
        v_depths := v_depths || (v_depth + 1);
      else
        raise exception 'invalid request'
          using errcode = '22023';
      end if;
    end loop;
  end loop;

  perform pg_catalog.pg_advisory_xact_lock(
    ('x' || pg_catalog.substr(pg_catalog.md5(p_product_id::text), 1, 16))::bit(64)::bigint
  );

  select product_row.id
  into v_product_id
  from public.products as product_row
  where product_row.id = p_product_id;

  if v_product_id is null then
    raise exception 'not found'
      using errcode = 'P0002';
  end if;

  select
    pg_catalog.count(*)::integer
  into v_variant_count
  from public.product_variants as variant_row
  where variant_row.product_id = p_product_id;

  if p_variant_id is null then
    v_is_default := p_is_default or v_variant_count = 0;
  else
    select variant_row.id, variant_row.product_id, variant_row.is_default
    into v_existing_id, v_existing_product, v_existing_default
    from public.product_variants as variant_row
    where variant_row.id = p_variant_id;

    if v_existing_id is null then
      raise exception 'not found'
        using errcode = 'P0002';
    end if;

    if v_existing_product is distinct from p_product_id then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;

    if v_existing_default and not p_is_default then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;

    v_is_default := p_is_default;
  end if;

  if v_is_default then
    update public.product_variants as variant_row
    set is_default = false
    where variant_row.product_id = p_product_id
      and variant_row.is_default = true
      and (p_variant_id is null or variant_row.id <> p_variant_id);
  end if;

  if p_variant_id is null then
    v_saved_id := pg_catalog.gen_random_uuid();

    insert into public.product_variants (
      id,
      product_id,
      sku,
      name,
      color_name,
      color_hex,
      racket_weight_class,
      grip_size,
      shoe_size,
      clothing_size,
      unit,
      price,
      compare_at_price,
      cost_price,
      barcode,
      attributes,
      is_default,
      is_active,
      sort_order
    ) values (
      v_saved_id,
      p_product_id,
      v_sku,
      v_name,
      v_color_name,
      v_color_hex,
      v_racket_weight_class,
      v_grip_size,
      v_shoe_size,
      v_clothing_size,
      v_unit,
      p_price,
      p_compare_at_price,
      case
        when p_cost_mode = 'set' then p_cost_price
        else null
      end,
      case
        when p_barcode_mode = 'set' then v_barcode
        else null
      end,
      p_attributes,
      v_is_default,
      p_is_active,
      p_sort_order
    );
  else
    v_saved_id := p_variant_id;

    update public.product_variants as variant_row
    set
      sku = v_sku,
      name = v_name,
      color_name = v_color_name,
      color_hex = v_color_hex,
      racket_weight_class = v_racket_weight_class,
      grip_size = v_grip_size,
      shoe_size = v_shoe_size,
      clothing_size = v_clothing_size,
      unit = v_unit,
      price = p_price,
      compare_at_price = p_compare_at_price,
      attributes = p_attributes,
      is_default = v_is_default,
      is_active = p_is_active,
      sort_order = p_sort_order
    where variant_row.id = p_variant_id
      and variant_row.product_id = p_product_id;

    if not found then
      raise exception 'not found'
        using errcode = 'P0002';
    end if;

    if p_cost_mode = 'set' then
      update public.product_variants as variant_row
      set cost_price = p_cost_price
      where variant_row.id = p_variant_id
        and variant_row.product_id = p_product_id;
    elsif p_cost_mode = 'clear' then
      update public.product_variants as variant_row
      set cost_price = null
      where variant_row.id = p_variant_id
        and variant_row.product_id = p_product_id;
    end if;

    if p_barcode_mode = 'set' then
      update public.product_variants as variant_row
      set barcode = v_barcode
      where variant_row.id = p_variant_id
        and variant_row.product_id = p_product_id;
    elsif p_barcode_mode = 'clear' then
      update public.product_variants as variant_row
      set barcode = null
      where variant_row.id = p_variant_id
        and variant_row.product_id = p_product_id;
    end if;
  end if;

  return query select v_saved_id as variant_id;
end;
$$;

comment on function public.save_cms_product_variant(
  uuid, uuid, text, text, text, text, text, text, text, text, text,
  numeric, numeric, text, numeric, text, text, jsonb, boolean, boolean, integer
) is
  'CMS variant create/update. SECURITY INVOKER, VOLATILE, empty search_path. '
  'Authorizes via is_staff_or_admin(). Validates product and variant ownership '
  'under caller RLS; product_id is immutable. SKU is trimmed and internal '
  'whitespace collapsed to one space (case preserved, 1..80 chars). '
  'p_cost_mode and p_barcode_mode are unchanged|clear|set so edits never '
  'read or silently clear protected columns. First variant becomes default. '
  'Unsetting the current default without selecting another in this call is '
  'rejected. Default switches take a per-product transaction advisory lock, '
  'unset the prior default, then set the target. Returns only variant_id. '
  'EXECUTE granted to authenticated and service_role only.';

revoke all on function public.save_cms_product_variant(
  uuid, uuid, text, text, text, text, text, text, text, text, text,
  numeric, numeric, text, numeric, text, text, jsonb, boolean, boolean, integer
) from public;
revoke all on function public.save_cms_product_variant(
  uuid, uuid, text, text, text, text, text, text, text, text, text,
  numeric, numeric, text, numeric, text, text, jsonb, boolean, boolean, integer
) from anon;
revoke all on function public.save_cms_product_variant(
  uuid, uuid, text, text, text, text, text, text, text, text, text,
  numeric, numeric, text, numeric, text, text, jsonb, boolean, boolean, integer
) from authenticated;
revoke all on function public.save_cms_product_variant(
  uuid, uuid, text, text, text, text, text, text, text, text, text,
  numeric, numeric, text, numeric, text, text, jsonb, boolean, boolean, integer
) from service_role;

grant execute on function public.save_cms_product_variant(
  uuid, uuid, text, text, text, text, text, text, text, text, text,
  numeric, numeric, text, numeric, text, text, jsonb, boolean, boolean, integer
) to authenticated, service_role;
