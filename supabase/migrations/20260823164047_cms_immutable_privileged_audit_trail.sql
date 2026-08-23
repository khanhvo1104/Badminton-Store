-- TASK-042: canonical immutable CMS privileged audit ledger.
--
-- Append-only cms_privileged_audit_events captures semantic privileged mutations
-- transactionally from trusted sources (catalog writes, inventory_history,
-- order_status_history for staff transitions, staff_management_events).
-- Customer checkout history is excluded. Actor identity comes from auth.uid()
-- or immutable trusted source columns — never user-editable metadata.
--
-- Direct INSERT/UPDATE/DELETE on the ledger are denied for PUBLIC/anon/
-- authenticated. Reads are admin-only via list_cms_privileged_audit_events.

-- ---------------------------------------------------------------------------
-- Ledger table
-- ---------------------------------------------------------------------------
create table public.cms_privileged_audit_events (
  id uuid primary key default gen_random_uuid(),
  occurred_at timestamptz not null default timezone('utc', now()),
  actor_id uuid not null
    references public.profiles (id) on delete restrict,
  entity_type text not null
    constraint cms_privileged_audit_events_entity_type_check
      check (
        entity_type in (
          'category',
          'brand',
          'product',
          'variant',
          'inventory',
          'product_media',
          'order',
          'staff'
        )
      ),
  entity_id uuid not null,
  action text not null
    constraint cms_privileged_audit_events_action_check
      check (
        action in (
          'create',
          'update',
          'delete',
          'activate',
          'deactivate',
          'status_change',
          'adjust',
          'set_primary',
          'reorder',
          'status_transition',
          'annotate_transition',
          'invite',
          'promote',
          'demote'
        )
      ),
  metadata jsonb not null default '{}'::jsonb,
  constraint cms_privileged_audit_events_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

comment on table public.cms_privileged_audit_events is
  'Immutable canonical audit ledger for privileged CMS mutations. INSERT is '
  'trusted-backend only via append_cms_privileged_audit_event; SELECT is '
  'admin-only through list_cms_privileged_audit_events.';

create index cms_privileged_audit_events_occurred_id_idx
  on public.cms_privileged_audit_events (occurred_at desc, id desc);

create index cms_privileged_audit_events_entity_idx
  on public.cms_privileged_audit_events (
    entity_type,
    entity_id,
    occurred_at desc,
    id desc
  );

create index cms_privileged_audit_events_actor_idx
  on public.cms_privileged_audit_events (
    actor_id,
    occurred_at desc,
    id desc
  );

create index cms_privileged_audit_events_action_idx
  on public.cms_privileged_audit_events (
    action,
    occurred_at desc,
    id desc
  );

alter table public.cms_privileged_audit_events enable row level security;

create policy cms_privileged_audit_events_admin_select
  on public.cms_privileged_audit_events for select
  to authenticated
  using (public.is_admin());

comment on policy cms_privileged_audit_events_admin_select
  on public.cms_privileged_audit_events is
  'Active admins may read privileged audit events. Mutations are denied.';

revoke all on table public.cms_privileged_audit_events
  from public, anon, authenticated;
grant select on table public.cms_privileged_audit_events to authenticated;
grant all on table public.cms_privileged_audit_events to service_role;

-- ---------------------------------------------------------------------------
-- Metadata validation (allowlisted keys only; fail closed)
-- ---------------------------------------------------------------------------
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
  v_key text;
  v_allowed text[];
begin
  if p_metadata is null or jsonb_typeof(p_metadata) <> 'object' then
    return false;
  end if;

  for v_key in
    select jsonb_object_keys.key
    from jsonb_object_keys(p_metadata) as jsonb_object_keys(key)
  loop
    v_allowed := case
      when p_entity_type = 'category' and p_action in ('create', 'update', 'activate', 'deactivate')
        then array['slug', 'name', 'is_active', 'parent_changed', 'sort_order_changed', 'image_changed']
      when p_entity_type = 'brand' and p_action in ('create', 'update', 'activate', 'deactivate')
        then array['slug', 'name', 'is_active', 'sort_order_changed', 'logo_changed']
      when p_entity_type = 'product' and p_action in ('create', 'update', 'activate', 'deactivate', 'status_change')
        then array['slug', 'name', 'status', 'previous_status', 'is_featured_changed', 'category_changed', 'brand_changed']
      when p_entity_type = 'variant' and p_action in ('create', 'update', 'activate', 'deactivate')
        then array['product_id', 'sku', 'name', 'is_active', 'is_default_changed', 'price_changed']
      when p_entity_type = 'inventory' and p_action = 'adjust'
        then array['operation', 'reason', 'on_hand_before', 'on_hand_after', 'reorder_changed', 'backorder_changed']
      when p_entity_type = 'product_media' and p_action in ('create', 'update', 'delete', 'set_primary', 'reorder')
        then array['product_id', 'variant_scope', 'is_primary', 'sort_order']
      when p_entity_type = 'order' and p_action in ('status_transition', 'annotate_transition')
        then array['from_status', 'to_status', 'has_note']
      when p_entity_type = 'staff' and p_action in ('invite', 'activate', 'deactivate', 'promote', 'demote')
        then array['target_id', 'previous_role', 'new_role', 'previous_is_active', 'new_is_active']
      else array[]::text[]
    end;

    if not (v_key = any (v_allowed)) then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

comment on function public.validate_cms_privileged_audit_metadata(text, text, jsonb) is
  'Allowlisted metadata key guard for cms_privileged_audit_events. IMMUTABLE, '
  'empty search_path. Used by append_cms_privileged_audit_event.';

revoke all on function public.validate_cms_privileged_audit_metadata(text, text, jsonb)
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Trusted append path
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
    coalesce(p_occurred_at, timezone('utc', now())),
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

comment on function public.append_cms_privileged_audit_event(uuid, text, uuid, text, jsonb, timestamptz) is
  'Trusted append-only writer for cms_privileged_audit_events. SECURITY DEFINER, '
  'empty search_path. Validates actor profile and allowlisted metadata. '
  'EXECUTE revoked from client roles; invoked by trigger helpers only.';

revoke all on function public.append_cms_privileged_audit_event(uuid, text, uuid, text, jsonb, timestamptz)
  from public, anon, authenticated, service_role;
grant execute on function public.append_cms_privileged_audit_event(uuid, text, uuid, text, jsonb, timestamptz)
  to service_role;

-- ---------------------------------------------------------------------------
-- Immutability boundaries
-- ---------------------------------------------------------------------------
create or replace function public.enforce_cms_privileged_audit_insert_boundary()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_setting('app.cms_audit_internal', true) = '1' then
    return new;
  end if;

  raise exception 'not authorized'
    using errcode = '42501';
end;
$$;

comment on function public.enforce_cms_privileged_audit_insert_boundary() is
  'Blocks direct INSERT on cms_privileged_audit_events outside append helper. '
  'SECURITY INVOKER, empty search_path. Invoked solely by '
  'cms_privileged_audit_events_enforce_insert.';

revoke all on function public.enforce_cms_privileged_audit_insert_boundary()
  from public, anon, authenticated, service_role;
grant execute on function public.enforce_cms_privileged_audit_insert_boundary()
  to service_role;

create trigger cms_privileged_audit_events_enforce_insert
before insert on public.cms_privileged_audit_events
for each row
execute function public.enforce_cms_privileged_audit_insert_boundary();

create or replace function public.prevent_cms_privileged_audit_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'DELETE'
     and current_setting('app.cms_audit_test_cleanup', true) = '1'
     and session_user = 'postgres' then
    return old;
  end if;

  raise exception 'cms_privileged_audit_events is immutable'
    using errcode = '55000';
end;
$$;

comment on function public.prevent_cms_privileged_audit_mutation() is
  'Blocks UPDATE/DELETE on cms_privileged_audit_events. DELETE allowed only '
  'for postgres superuser fixtures when app.cms_audit_test_cleanup=1. '
  'SECURITY INVOKER, empty search_path.';

revoke all on function public.prevent_cms_privileged_audit_mutation()
  from public, anon, authenticated, service_role;
grant execute on function public.prevent_cms_privileged_audit_mutation()
  to service_role;

create trigger cms_privileged_audit_events_prevent_mutation
before update or delete on public.cms_privileged_audit_events
for each row
execute function public.prevent_cms_privileged_audit_mutation();

-- ---------------------------------------------------------------------------
-- Actor resolution for catalog/media triggers
-- ---------------------------------------------------------------------------
create or replace function public.cms_audit_resolve_staff_actor()
returns uuid
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_actor uuid;
begin
  v_actor := auth.uid();
  if v_actor is null then
    return null;
  end if;

  if not public.is_staff_or_admin() then
    return null;
  end if;

  return v_actor;
end;
$$;

comment on function public.cms_audit_resolve_staff_actor() is
  'Returns auth.uid() when the session is an active staff/admin CMS actor.';

revoke all on function public.cms_audit_resolve_staff_actor()
  from public, anon, authenticated, service_role;
grant execute on function public.cms_audit_resolve_staff_actor()
  to service_role;

-- ---------------------------------------------------------------------------
-- Category / brand / product catalog triggers
-- ---------------------------------------------------------------------------
create or replace function public.cms_audit_record_category_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_action text;
  v_metadata jsonb;
begin
  v_actor := public.cms_audit_resolve_staff_actor();
  if v_actor is null then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_action := 'create';
    v_metadata := jsonb_build_object(
      'slug', new.slug,
      'name', new.name,
      'is_active', new.is_active
    );
    perform public.append_cms_privileged_audit_event(
      v_actor, 'category', new.id, v_action, v_metadata
    );
    return new;
  elsif tg_op = 'UPDATE' then
    if new.is_active is distinct from old.is_active then
      v_action := case when new.is_active then 'activate' else 'deactivate' end;
    else
      v_action := 'update';
    end if;

    v_metadata := jsonb_build_object(
      'slug', new.slug,
      'name', new.name,
      'is_active', new.is_active,
      'parent_changed', new.parent_id is distinct from old.parent_id,
      'sort_order_changed', new.sort_order is distinct from old.sort_order,
      'image_changed', new.image_path is distinct from old.image_path
    );
    perform public.append_cms_privileged_audit_event(
      v_actor, 'category', new.id, v_action, v_metadata
    );
    return new;
  end if;

  return coalesce(new, old);
end;
$$;

revoke all on function public.cms_audit_record_category_change() from public, anon, authenticated, service_role;
grant execute on function public.cms_audit_record_category_change() to service_role;

create trigger categories_cms_privileged_audit
after insert or update on public.categories
for each row
execute function public.cms_audit_record_category_change();

create or replace function public.cms_audit_record_brand_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_action text;
  v_metadata jsonb;
begin
  v_actor := public.cms_audit_resolve_staff_actor();
  if v_actor is null then
    return coalesce(new, old);
  end if;

  if tg_op = 'INSERT' then
    perform public.append_cms_privileged_audit_event(
      v_actor,
      'brand',
      new.id,
      'create',
      jsonb_build_object(
        'slug', new.slug,
        'name', new.name,
        'is_active', new.is_active
      )
    );
    return new;
  elsif tg_op = 'UPDATE' then
    if new.is_active is distinct from old.is_active then
      v_action := case when new.is_active then 'activate' else 'deactivate' end;
    else
      v_action := 'update';
    end if;

    v_metadata := jsonb_build_object(
      'slug', new.slug,
      'name', new.name,
      'is_active', new.is_active,
      'sort_order_changed', new.sort_order is distinct from old.sort_order,
      'logo_changed', new.logo_path is distinct from old.logo_path
    );
    perform public.append_cms_privileged_audit_event(
      v_actor, 'brand', new.id, v_action, v_metadata
    );
    return new;
  end if;

  return coalesce(new, old);
end;
$$;

revoke all on function public.cms_audit_record_brand_change() from public, anon, authenticated, service_role;
grant execute on function public.cms_audit_record_brand_change() to service_role;

create trigger brands_cms_privileged_audit
after insert or update on public.brands
for each row
execute function public.cms_audit_record_brand_change();

create or replace function public.cms_audit_record_product_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_action text;
  v_metadata jsonb;
begin
  v_actor := public.cms_audit_resolve_staff_actor();
  if v_actor is null then
    return coalesce(new, old);
  end if;

  if tg_op = 'INSERT' then
    perform public.append_cms_privileged_audit_event(
      v_actor,
      'product',
      new.id,
      'create',
      jsonb_build_object(
        'slug', new.slug,
        'name', new.name,
        'status', new.status
      )
    );
    return new;
  elsif tg_op = 'UPDATE' then
    if new.status is distinct from old.status then
      v_action := 'status_change';
      v_metadata := jsonb_build_object(
        'slug', new.slug,
        'name', new.name,
        'status', new.status,
        'previous_status', old.status
      );
    else
      v_action := 'update';
      v_metadata := jsonb_build_object(
        'slug', new.slug,
        'name', new.name,
        'status', new.status,
        'is_featured_changed', new.is_featured is distinct from old.is_featured,
        'category_changed', new.category_id is distinct from old.category_id,
        'brand_changed', new.brand_id is distinct from old.brand_id
      );
    end if;

    perform public.append_cms_privileged_audit_event(
      v_actor, 'product', new.id, v_action, v_metadata
    );
    return new;
  end if;

  return coalesce(new, old);
end;
$$;

revoke all on function public.cms_audit_record_product_change() from public, anon, authenticated, service_role;
grant execute on function public.cms_audit_record_product_change() to service_role;

create trigger products_cms_privileged_audit
after insert or update on public.products
for each row
execute function public.cms_audit_record_product_change();

create or replace function public.cms_audit_record_variant_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_action text;
  v_metadata jsonb;
begin
  v_actor := public.cms_audit_resolve_staff_actor();
  if v_actor is null then
    return coalesce(new, old);
  end if;

  if tg_op = 'INSERT' then
    perform public.append_cms_privileged_audit_event(
      v_actor,
      'variant',
      new.id,
      'create',
      jsonb_build_object(
        'product_id', new.product_id,
        'sku', new.sku,
        'name', new.name,
        'is_active', new.is_active
      )
    );
    return new;
  elsif tg_op = 'UPDATE' then
    if new.is_active is distinct from old.is_active then
      v_action := case when new.is_active then 'activate' else 'deactivate' end;
    else
      v_action := 'update';
    end if;

    v_metadata := jsonb_build_object(
      'product_id', new.product_id,
      'sku', new.sku,
      'name', new.name,
      'is_active', new.is_active,
      'is_default_changed', new.is_default is distinct from old.is_default,
      'price_changed', new.price is distinct from old.price
    );
    perform public.append_cms_privileged_audit_event(
      v_actor, 'variant', new.id, v_action, v_metadata
    );
    return new;
  end if;

  return coalesce(new, old);
end;
$$;

revoke all on function public.cms_audit_record_variant_change() from public, anon, authenticated, service_role;
grant execute on function public.cms_audit_record_variant_change() to service_role;

create trigger product_variants_cms_privileged_audit
after insert or update on public.product_variants
for each row
execute function public.cms_audit_record_variant_change();

-- ---------------------------------------------------------------------------
-- Product media triggers
-- ---------------------------------------------------------------------------
create or replace function public.cms_audit_record_product_media_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_action text;
  v_entity_id uuid;
  v_metadata jsonb;
  v_scope text;
begin
  v_actor := public.cms_audit_resolve_staff_actor();
  if v_actor is null then
    return coalesce(new, old);
  end if;

  if tg_op = 'DELETE' then
    v_scope := case when old.variant_id is null then 'general' else 'variant' end;
    perform public.append_cms_privileged_audit_event(
      v_actor,
      'product_media',
      old.id,
      'delete',
      jsonb_build_object(
        'product_id', old.product_id,
        'variant_scope', v_scope,
        'is_primary', old.is_primary,
        'sort_order', old.sort_order
      )
    );
    return old;
  end if;

  v_scope := case when new.variant_id is null then 'general' else 'variant' end;

  if tg_op = 'INSERT' then
    perform public.append_cms_privileged_audit_event(
      v_actor,
      'product_media',
      new.id,
      'create',
      jsonb_build_object(
        'product_id', new.product_id,
        'variant_scope', v_scope,
        'is_primary', new.is_primary,
        'sort_order', new.sort_order
      )
    );
    return new;
  end if;

  v_entity_id := new.id;

  if new.is_primary = true and old.is_primary is distinct from true then
    v_action := 'set_primary';
  elsif new.sort_order is distinct from old.sort_order
        and new.is_primary is not distinct from old.is_primary
        and new.storage_path is not distinct from old.storage_path
        and new.alt_text is not distinct from old.alt_text
        and new.variant_id is not distinct from old.variant_id then
    v_action := 'reorder';
  else
    v_action := 'update';
  end if;

  v_metadata := jsonb_build_object(
    'product_id', new.product_id,
    'variant_scope', v_scope,
    'is_primary', new.is_primary,
    'sort_order', new.sort_order
  );

  perform public.append_cms_privileged_audit_event(
    v_actor, 'product_media', v_entity_id, v_action, v_metadata
  );
  return new;
end;
$$;

revoke all on function public.cms_audit_record_product_media_change() from public, anon, authenticated, service_role;
grant execute on function public.cms_audit_record_product_media_change() to service_role;

create trigger product_images_cms_privileged_audit
after insert or update or delete on public.product_images
for each row
execute function public.cms_audit_record_product_media_change();

-- ---------------------------------------------------------------------------
-- Inventory history mirror
-- ---------------------------------------------------------------------------
create or replace function public.cms_audit_record_inventory_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.append_cms_privileged_audit_event(
    new.actor_id,
    'inventory',
    new.variant_id,
    'adjust',
    jsonb_build_object(
      'operation', new.operation,
      'reason', new.reason,
      'on_hand_before', new.quantity_on_hand_before,
      'on_hand_after', new.quantity_on_hand_after,
      'reorder_changed', new.reorder_level_before is distinct from new.reorder_level_after,
      'backorder_changed', new.allow_backorder_before is distinct from new.allow_backorder_after
    ),
    new.created_at
  );
  return new;
end;
$$;

revoke all on function public.cms_audit_record_inventory_history() from public, anon, authenticated, service_role;
grant execute on function public.cms_audit_record_inventory_history() to service_role;

create trigger inventory_history_cms_privileged_audit
after insert on public.inventory_history
for each row
execute function public.cms_audit_record_inventory_history();

-- ---------------------------------------------------------------------------
-- Order status history (staff transitions only; skip checkout seed rows)
-- ---------------------------------------------------------------------------
create or replace function public.cms_audit_is_staff_profile(p_profile_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles as profile_row
    where profile_row.id = p_profile_id
      and profile_row.role in ('staff', 'admin')
      and profile_row.is_active = true
  );
$$;

revoke all on function public.cms_audit_is_staff_profile(uuid) from public, anon, authenticated, service_role;
grant execute on function public.cms_audit_is_staff_profile(uuid) to service_role;

create or replace function public.cms_audit_record_order_status_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_metadata jsonb;
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
      timezone('utc', now())
    );
  end if;

  return new;
end;
$$;

revoke all on function public.cms_audit_record_order_status_history() from public, anon, authenticated, service_role;
grant execute on function public.cms_audit_record_order_status_history() to service_role;

create trigger order_status_history_cms_privileged_audit
after insert or update of note on public.order_status_history
for each row
execute function public.cms_audit_record_order_status_history();

-- ---------------------------------------------------------------------------
-- Staff management events mirror (trusted actor_id column)
-- ---------------------------------------------------------------------------
create or replace function public.cms_audit_record_staff_management_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.append_cms_privileged_audit_event(
    new.actor_id,
    'staff',
    coalesce(new.target_id, new.id),
    new.action,
    jsonb_build_object(
      'target_id', new.target_id,
      'previous_role', new.previous_role,
      'new_role', new.new_role,
      'previous_is_active', new.previous_is_active,
      'new_is_active', new.new_is_active
    ),
    new.created_at
  );
  return new;
end;
$$;

revoke all on function public.cms_audit_record_staff_management_event() from public, anon, authenticated, service_role;
grant execute on function public.cms_audit_record_staff_management_event() to service_role;

create trigger staff_management_events_cms_privileged_audit
after insert on public.staff_management_events
for each row
execute function public.cms_audit_record_staff_management_event();

-- ---------------------------------------------------------------------------
-- Admin read RPC (bounded cursor pagination + filters)
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
    'all',
    'category',
    'brand',
    'product',
    'variant',
    'inventory',
    'product_media',
    'order',
    'staff'
  ) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_action := coalesce(p_action, 'all');
  if v_action not in (
    'all',
    'create',
    'update',
    'delete',
    'activate',
    'deactivate',
    'status_change',
    'adjust',
    'set_primary',
    'reorder',
    'status_transition',
    'annotate_transition',
    'invite',
    'promote',
    'demote'
  ) then
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
        or p_cursor_id is null
        or (event_row.occurred_at, event_row.id)
           < (p_cursor_occurred_at, p_cursor_id)
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

comment on function public.list_cms_privileged_audit_events(
  text, text, uuid, timestamptz, timestamptz, timestamptz, uuid, integer
) is
  'Admin-only privileged audit explorer with bounded cursor pagination and '
  'filters. STABLE, SECURITY DEFINER, empty search_path. Returns allowlisted '
  'metadata only; never exposes raw history payloads or PII.';

revoke all on function public.list_cms_privileged_audit_events(
  text, text, uuid, timestamptz, timestamptz, timestamptz, uuid, integer
) from public, anon, authenticated, service_role;
grant execute on function public.list_cms_privileged_audit_events(
  text, text, uuid, timestamptz, timestamptz, timestamptz, uuid, integer
) to authenticated;
