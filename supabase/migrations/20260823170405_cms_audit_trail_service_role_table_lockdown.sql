-- TASK-042 review follow-up: close service_role table write bypass on the audit
-- ledger. Trigger SECURITY DEFINER append helpers remain owner-executed without
-- caller table privileges. Also remove unused PL/pgSQL vars for clean db lint.

-- ---------------------------------------------------------------------------
-- Ledger table: service_role may not write (GUC bypass insufficient alone)
-- ---------------------------------------------------------------------------
revoke all on table public.cms_privileged_audit_events from service_role;
grant select on table public.cms_privileged_audit_events to service_role;

-- ---------------------------------------------------------------------------
-- db lint: drop unused PL/pgSQL declarations (behavior unchanged)
-- ---------------------------------------------------------------------------
create or replace function public.cms_audit_metadata_value_valid(
  p_entity_type text,
  p_action text,
  p_metadata jsonb
)
returns boolean
language plpgsql
immutable
security invoker
set search_path = ''
as $$
declare
  v_text text;
  v_num numeric;
begin
  if p_entity_type in ('category', 'brand', 'product') then
    v_text := p_metadata->>'slug';
    if v_text is null
       or pg_catalog.char_length(v_text) < 1
       or pg_catalog.char_length(v_text) > 120
       or v_text !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    then
      return false;
    end if;

    v_text := p_metadata->>'name';
    if v_text is null
       or pg_catalog.char_length(v_text) < 1
       or pg_catalog.char_length(v_text) > 120
    then
      return false;
    end if;
  end if;

  if p_entity_type = 'category'
     and p_action in ('create', 'update', 'activate', 'deactivate')
  then
    if jsonb_typeof(p_metadata->'is_active') <> 'boolean' then
      return false;
    end if;
    if p_action = 'update' then
      if jsonb_typeof(p_metadata->'parent_changed') <> 'boolean'
         or jsonb_typeof(p_metadata->'sort_order_changed') <> 'boolean'
         or jsonb_typeof(p_metadata->'image_changed') <> 'boolean'
      then
        return false;
      end if;
    end if;
  elsif p_entity_type = 'brand'
        and p_action in ('create', 'update', 'activate', 'deactivate')
  then
    if jsonb_typeof(p_metadata->'is_active') <> 'boolean' then
      return false;
    end if;
    if p_action = 'update' then
      if jsonb_typeof(p_metadata->'sort_order_changed') <> 'boolean'
         or jsonb_typeof(p_metadata->'logo_changed') <> 'boolean'
      then
        return false;
      end if;
    end if;
  elsif p_entity_type = 'product'
        and p_action in ('create', 'update', 'status_change')
  then
    v_text := p_metadata->>'status';
    if v_text not in ('draft', 'active', 'inactive', 'archived') then
      return false;
    end if;
    if p_action = 'status_change' then
      v_text := p_metadata->>'previous_status';
      if v_text not in ('draft', 'active', 'inactive', 'archived') then
        return false;
      end if;
    end if;
    if p_action = 'update' then
      if jsonb_typeof(p_metadata->'is_featured_changed') <> 'boolean'
         or jsonb_typeof(p_metadata->'category_changed') <> 'boolean'
         or jsonb_typeof(p_metadata->'brand_changed') <> 'boolean'
      then
        return false;
      end if;
    end if;
  elsif p_entity_type = 'variant'
        and p_action in ('create', 'update', 'activate', 'deactivate')
  then
    v_text := p_metadata->>'product_id';
    if v_text is null or v_text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then
      return false;
    end if;

    v_text := p_metadata->>'sku';
    if v_text is null
       or pg_catalog.char_length(v_text) < 1
       or pg_catalog.char_length(v_text) > 80
    then
      return false;
    end if;

    if jsonb_typeof(p_metadata->'name') = 'null' then
      null;
    elsif jsonb_typeof(p_metadata->'name') = 'string' then
      v_text := p_metadata->>'name';
      if v_text is null
         or pg_catalog.char_length(v_text) < 1
         or pg_catalog.char_length(v_text) > 200
      then
        return false;
      end if;
    else
      return false;
    end if;

    if jsonb_typeof(p_metadata->'is_active') <> 'boolean' then
      return false;
    end if;

    if p_action in ('update', 'activate', 'deactivate') then
      if jsonb_typeof(p_metadata->'is_default_changed') <> 'boolean'
         or jsonb_typeof(p_metadata->'price_changed') <> 'boolean'
      then
        return false;
      end if;
    end if;
  elsif p_entity_type = 'inventory' and p_action = 'adjust' then
    v_text := p_metadata->>'operation';
    if v_text not in (
      'add_stock',
      'remove_stock',
      'set_on_hand',
      'set_reorder_level',
      'set_allow_backorder'
    ) then
      return false;
    end if;

    v_text := p_metadata->>'reason';
    if v_text is null
       or pg_catalog.char_length(pg_catalog.btrim(v_text)) < 1
       or pg_catalog.char_length(v_text) > 80
    then
      return false;
    end if;

    if jsonb_typeof(p_metadata->'on_hand_before') <> 'number'
       or jsonb_typeof(p_metadata->'on_hand_after') <> 'number'
    then
      return false;
    end if;

    v_num := (p_metadata->>'on_hand_before')::numeric;
    if v_num < 0 or v_num <> pg_catalog.trunc(v_num) then
      return false;
    end if;
    v_num := (p_metadata->>'on_hand_after')::numeric;
    if v_num < 0 or v_num <> pg_catalog.trunc(v_num) then
      return false;
    end if;

    if jsonb_typeof(p_metadata->'reorder_changed') <> 'boolean'
       or jsonb_typeof(p_metadata->'backorder_changed') <> 'boolean'
    then
      return false;
    end if;
  elsif p_entity_type = 'product_media'
        and p_action in ('create', 'update', 'delete', 'set_primary', 'reorder')
  then
    v_text := p_metadata->>'product_id';
    if v_text is null or v_text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then
      return false;
    end if;

    v_text := p_metadata->>'variant_scope';
    if v_text not in ('general', 'variant') then
      return false;
    end if;

    if jsonb_typeof(p_metadata->'is_primary') <> 'boolean' then
      return false;
    end if;

    if jsonb_typeof(p_metadata->'sort_order') <> 'number' then
      return false;
    end if;
    v_num := (p_metadata->>'sort_order')::numeric;
    if v_num < -1000000 or v_num > 1000000 or v_num <> pg_catalog.trunc(v_num) then
      return false;
    end if;
  elsif p_entity_type = 'order'
        and p_action in ('status_transition', 'annotate_transition')
  then
    v_text := p_metadata->>'from_status';
    if v_text not in (
      'pending', 'confirmed', 'preparing', 'shipping',
      'delivered', 'cancelled', 'returned'
    ) then
      return false;
    end if;
    v_text := p_metadata->>'to_status';
    if v_text not in (
      'pending', 'confirmed', 'preparing', 'shipping',
      'delivered', 'cancelled', 'returned'
    ) then
      return false;
    end if;

    if jsonb_typeof(p_metadata->'has_note') <> 'boolean' then
      return false;
    end if;
  elsif p_entity_type = 'staff'
        and p_action in ('invite', 'activate', 'deactivate', 'promote', 'demote')
  then
    v_text := p_metadata->>'target_id';
    if v_text is null or v_text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then
      return false;
    end if;

    v_text := p_metadata->>'previous_role';
    if v_text not in ('customer', 'staff', 'admin') then
      return false;
    end if;
    v_text := p_metadata->>'new_role';
    if v_text not in ('staff', 'admin') then
      return false;
    end if;

    if jsonb_typeof(p_metadata->'previous_is_active') <> 'boolean'
       or jsonb_typeof(p_metadata->'new_is_active') <> 'boolean'
    then
      return false;
    end if;
  else
    return false;
  end if;

  return true;
end;
$$;

create or replace function public.validate_cms_privileged_audit_metadata(
  p_entity_type text,
  p_action text,
  p_metadata jsonb
)
returns boolean
language plpgsql
immutable
security invoker
set search_path = ''
as $$
declare
  v_required text[];
  v_key text;
  v_key_count integer;
begin
  if p_metadata is null or jsonb_typeof(p_metadata) <> 'object' then
    return false;
  end if;

  v_required := case
    when p_entity_type = 'category' and p_action = 'create'
      then array['slug', 'name', 'is_active']
    when p_entity_type = 'category' and p_action in ('activate', 'deactivate')
      then array['slug', 'name', 'is_active']
    when p_entity_type = 'category' and p_action = 'update'
      then array[
        'slug', 'name', 'is_active', 'parent_changed',
        'sort_order_changed', 'image_changed'
      ]
    when p_entity_type = 'brand' and p_action = 'create'
      then array['slug', 'name', 'is_active']
    when p_entity_type = 'brand' and p_action in ('activate', 'deactivate')
      then array['slug', 'name', 'is_active']
    when p_entity_type = 'brand' and p_action = 'update'
      then array[
        'slug', 'name', 'is_active', 'sort_order_changed', 'logo_changed'
      ]
    when p_entity_type = 'product' and p_action = 'create'
      then array['slug', 'name', 'status']
    when p_entity_type = 'product' and p_action = 'update'
      then array[
        'slug', 'name', 'status', 'is_featured_changed',
        'category_changed', 'brand_changed'
      ]
    when p_entity_type = 'product' and p_action = 'status_change'
      then array['slug', 'name', 'status', 'previous_status']
    when p_entity_type = 'variant' and p_action = 'create'
      then array['product_id', 'sku', 'name', 'is_active']
    when p_entity_type = 'variant' and p_action in ('activate', 'deactivate')
      then array[
        'product_id', 'sku', 'name', 'is_active', 'is_default_changed',
        'price_changed'
      ]
    when p_entity_type = 'variant' and p_action = 'update'
      then array[
        'product_id', 'sku', 'name', 'is_active', 'is_default_changed',
        'price_changed'
      ]
    when p_entity_type = 'inventory' and p_action = 'adjust'
      then array[
        'operation', 'reason', 'on_hand_before', 'on_hand_after',
        'reorder_changed', 'backorder_changed'
      ]
    when p_entity_type = 'product_media'
         and p_action in ('create', 'update', 'delete', 'set_primary', 'reorder')
      then array['product_id', 'variant_scope', 'is_primary', 'sort_order']
    when p_entity_type = 'order'
         and p_action in ('status_transition', 'annotate_transition')
      then array['from_status', 'to_status', 'has_note']
    when p_entity_type = 'staff'
         and p_action in ('invite', 'activate', 'deactivate', 'promote', 'demote')
      then array[
        'target_id', 'previous_role', 'new_role',
        'previous_is_active', 'new_is_active'
      ]
    else null
  end;

  if v_required is null then
    return false;
  end if;

  select count(*)::integer
  into v_key_count
  from jsonb_object_keys(p_metadata) as metadata_keys(key);

  if v_key_count <> coalesce(array_length(v_required, 1), 0) then
    return false;
  end if;

  foreach v_key in array v_required loop
    if not (p_metadata ? v_key) then
      return false;
    end if;
  end loop;

  if not public.cms_audit_metadata_value_valid(
    p_entity_type,
    p_action,
    p_metadata
  ) then
    return false;
  end if;

  return true;
end;
$$;
