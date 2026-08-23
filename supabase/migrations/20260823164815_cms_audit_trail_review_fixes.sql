-- TASK-042 review: harden audit writer EXECUTE, exact metadata schemas,
-- cursor validation, and defense-in-depth table CHECK.

-- ---------------------------------------------------------------------------
-- Timestamps: use now() defaults (no timezone reinterpretation)
-- ---------------------------------------------------------------------------
alter table public.cms_privileged_audit_events
  alter column occurred_at set default now();

-- ---------------------------------------------------------------------------
-- Exact metadata validation (required keys + bounded value domains)
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
  v_int integer;
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

    if p_action <> 'create' then
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
    if v_num <> pg_catalog.trunc(v_num)
       or v_num < -1000000
       or v_num > 1000000
    then
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

comment on function public.cms_audit_metadata_value_valid(text, text, jsonb) is
  'Bounded value-domain guard for cms_privileged_audit_events metadata. '
  'IMMUTABLE, empty search_path. Invoked only by validate_cms_privileged_audit_metadata.';

revoke all on function public.cms_audit_metadata_value_valid(text, text, jsonb)
  from public, anon, authenticated, service_role;

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
  v_text text;
  v_int integer;
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

comment on function public.validate_cms_privileged_audit_metadata(text, text, jsonb) is
  'Exact required-key and bounded value-domain guard for cms_privileged_audit_events. '
  'IMMUTABLE, empty search_path. Used by append helper and table CHECK.';

revoke all on function public.validate_cms_privileged_audit_metadata(text, text, jsonb)
  from public, anon, authenticated, service_role;

alter table public.cms_privileged_audit_events
  add constraint cms_privileged_audit_events_metadata_valid_check
  check (
    public.validate_cms_privileged_audit_metadata(entity_type, action, metadata)
  );

-- ---------------------------------------------------------------------------
-- Trusted append path: trigger-only, no API-role EXECUTE
-- ---------------------------------------------------------------------------
create or replace function public.append_cms_privileged_audit_event(
  p_actor_id uuid,
  p_entity_type text,
  p_entity_id uuid,
  p_action text,
  p_metadata jsonb default '{}'::jsonb,
  p_occurred_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_actor uuid;
  v_metadata jsonb;
begin
  if p_actor_id is null or p_entity_id is null then
    raise exception 'invalid audit event'
      using errcode = '22023';
  end if;

  select profile_row.id
  into v_actor
  from public.profiles as profile_row
  where profile_row.id = p_actor_id
    and profile_row.role in ('staff', 'admin')
    and profile_row.is_active = true;

  if v_actor is null then
    raise exception 'invalid audit event'
      using errcode = '22023';
  end if;

  v_metadata := coalesce(p_metadata, '{}'::jsonb);

  if not public.validate_cms_privileged_audit_metadata(
    p_entity_type,
    p_action,
    v_metadata
  ) then
    raise exception 'invalid audit event'
      using errcode = '22023';
  end if;

  perform set_config('app.cms_audit_internal', '1', true);

  insert into public.cms_privileged_audit_events (
    occurred_at,
    actor_id,
    entity_type,
    entity_id,
    action,
    metadata
  ) values (
    coalesce(p_occurred_at, now()),
    v_actor,
    p_entity_type,
    p_entity_id,
    p_action,
    v_metadata
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.append_cms_privileged_audit_event(uuid, text, uuid, text, jsonb, timestamptz)
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Revoke API-role EXECUTE from trigger-only helpers
-- ---------------------------------------------------------------------------
revoke all on function public.enforce_cms_privileged_audit_insert_boundary()
  from public, anon, authenticated, service_role;

revoke all on function public.prevent_cms_privileged_audit_mutation()
  from public, anon, authenticated, service_role;

revoke all on function public.cms_audit_resolve_staff_actor()
  from public, anon, authenticated, service_role;

revoke all on function public.cms_audit_is_staff_profile(uuid)
  from public, anon, authenticated, service_role;

revoke all on function public.cms_audit_record_category_change()
  from public, anon, authenticated, service_role;

revoke all on function public.cms_audit_record_brand_change()
  from public, anon, authenticated, service_role;

revoke all on function public.cms_audit_record_product_change()
  from public, anon, authenticated, service_role;

revoke all on function public.cms_audit_record_variant_change()
  from public, anon, authenticated, service_role;

revoke all on function public.cms_audit_record_product_media_change()
  from public, anon, authenticated, service_role;

revoke all on function public.cms_audit_record_inventory_history()
  from public, anon, authenticated, service_role;

revoke all on function public.cms_audit_record_order_status_history()
  from public, anon, authenticated, service_role;

revoke all on function public.cms_audit_record_staff_management_event()
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Order annotate uses now() for trusted in-transaction stamp
-- ---------------------------------------------------------------------------
create or replace function public.cms_audit_record_order_status_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.changed_by is null
     or not public.cms_audit_is_staff_profile(new.changed_by) then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.from_status is null then
      return new;
    end if;

    perform public.append_cms_privileged_audit_event(
      new.changed_by,
      'order',
      new.order_id,
      'status_transition',
      jsonb_build_object(
        'from_status', new.from_status,
        'to_status', new.to_status,
        'has_note', new.note is not null
      ),
      new.created_at
    );
    return new;
  end if;

  if tg_op = 'UPDATE'
     and old.note is null
     and new.note is not null then
    perform public.append_cms_privileged_audit_event(
      new.changed_by,
      'order',
      new.order_id,
      'annotate_transition',
      jsonb_build_object(
        'from_status', new.from_status,
        'to_status', new.to_status,
        'has_note', true
      ),
      now()
    );
  end if;

  return new;
end;
$$;

revoke all on function public.cms_audit_record_order_status_history()
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Admin read RPC: reject half-cursors
-- ---------------------------------------------------------------------------
create or replace function public.list_cms_privileged_audit_events(
  p_entity_type text default 'all',
  p_action text default 'all',
  p_actor_id uuid default null,
  p_occurred_from timestamptz default null,
  p_occurred_to timestamptz default null,
  p_cursor_occurred_at timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 25
)
returns table (
  event_id uuid,
  occurred_at timestamptz,
  actor_id uuid,
  actor_name text,
  entity_type text,
  entity_id uuid,
  action text,
  metadata jsonb,
  has_more boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_entity_type text;
  v_action text;
  v_limit integer;
  v_fetch integer;
begin
  if not public.is_admin() then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  v_entity_type := coalesce(p_entity_type, 'all');
  if v_entity_type not in (
    'all', 'category', 'brand', 'product', 'variant', 'inventory',
    'product_media', 'order', 'staff'
  ) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_action := coalesce(p_action, 'all');
  if v_action not in (
    'all', 'create', 'update', 'delete', 'activate', 'deactivate',
    'status_change', 'adjust', 'set_primary', 'reorder', 'status_transition',
    'annotate_transition', 'invite', 'promote', 'demote'
  ) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if (p_cursor_occurred_at is null) <> (p_cursor_id is null) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_occurred_from is not null
     and p_occurred_to is not null
     and p_occurred_from > p_occurred_to then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_limit is null or p_limit < 1 or p_limit > 50 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;
  v_limit := p_limit;
  v_fetch := v_limit + 1;

  return query
  with filtered as (
    select
      event_row.id as event_id,
      event_row.occurred_at,
      event_row.actor_id,
      actor_profile.full_name as actor_name,
      event_row.entity_type,
      event_row.entity_id,
      event_row.action,
      event_row.metadata
    from public.cms_privileged_audit_events as event_row
    inner join public.profiles as actor_profile
      on actor_profile.id = event_row.actor_id
    where (v_entity_type = 'all' or event_row.entity_type = v_entity_type)
      and (v_action = 'all' or event_row.action = v_action)
      and (p_actor_id is null or event_row.actor_id = p_actor_id)
      and (p_occurred_from is null or event_row.occurred_at >= p_occurred_from)
      and (p_occurred_to is null or event_row.occurred_at <= p_occurred_to)
      and (
        p_cursor_occurred_at is null
        or (
          event_row.occurred_at,
          event_row.id
        ) < (p_cursor_occurred_at, p_cursor_id)
      )
    order by event_row.occurred_at desc, event_row.id desc
    limit v_fetch
  ),
  numbered as (
    select
      filtered.*,
      row_number() over (
        order by filtered.occurred_at desc, filtered.event_id desc
      ) as row_num
    from filtered
  )
  select
    numbered.event_id,
    numbered.occurred_at,
    numbered.actor_id,
    numbered.actor_name,
    numbered.entity_type,
    numbered.entity_id,
    numbered.action,
    numbered.metadata,
    exists (
      select 1
      from numbered as overflow_row
      where overflow_row.row_num > v_limit
    ) as has_more
  from numbered
  where numbered.row_num <= v_limit;
end;
$$;

revoke all on function public.list_cms_privileged_audit_events(
  text, text, uuid, timestamptz, timestamptz, timestamptz, uuid, integer
) from public, anon, authenticated, service_role;
grant execute on function public.list_cms_privileged_audit_events(
  text, text, uuid, timestamptz, timestamptz, timestamptz, uuid, integer
) to authenticated;
