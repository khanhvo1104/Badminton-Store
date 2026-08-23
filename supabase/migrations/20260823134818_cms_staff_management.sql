-- TASK-041: admin-only CMS staff list, trusted mutations, and audit support.
--
-- list_cms_staff reads staff/admin profiles with PII-minimized fields and
-- joins auth.users for email under SECURITY DEFINER + is_admin().
--
-- update_cms_staff is the only trusted path for role/is_active changes on
-- staff/admin profiles from authenticated callers. A trigger blocks direct
-- role/is_active updates unless the trusted GUC is set by that RPC or the
-- caller is service_role (Edge Function profile assignment after invite).

-- ---------------------------------------------------------------------------
-- Audit support
-- ---------------------------------------------------------------------------
create table public.staff_management_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.profiles (id) on delete restrict,
  target_id uuid references public.profiles (id) on delete set null,
  action text not null
    constraint staff_management_events_action_check
      check (action in ('invite', 'activate', 'deactivate', 'promote', 'demote')),
  previous_role text,
  new_role text,
  previous_is_active boolean,
  new_is_active boolean,
  target_email text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint staff_management_events_target_email_length_check
    check (
      target_email is null
      or char_length(target_email) between 3 and 254
    )
);

comment on table public.staff_management_events is
  'Immutable audit trail for privileged staff-management actions. '
  'INSERT is trusted-backend only; SELECT is admin-only via RLS.';

create index staff_management_events_created_at_idx
  on public.staff_management_events (created_at desc);

create index staff_management_events_target_id_idx
  on public.staff_management_events (target_id);

alter table public.staff_management_events enable row level security;

create policy staff_management_events_admin_select
  on public.staff_management_events for select
  to authenticated
  using (public.is_admin());

comment on policy staff_management_events_admin_select
  on public.staff_management_events is
  'Active admins may read staff-management audit events.';

revoke all on table public.staff_management_events from public, anon, authenticated;
grant select on table public.staff_management_events to authenticated;
grant all on table public.staff_management_events to service_role;

-- ---------------------------------------------------------------------------
-- Trusted mutation boundary for profiles.role / profiles.is_active
-- ---------------------------------------------------------------------------
create or replace function public.enforce_staff_profile_mutation_boundary()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if new.role is not distinct from old.role
     and new.is_active is not distinct from old.is_active then
    return new;
  end if;

  if session_user in ('service_role', 'postgres') then
    return new;
  end if;

  if current_setting('app.trusted_staff_management', true) = '1' then
    return new;
  end if;

  raise exception 'not authorized'
    using errcode = '42501';
end;
$$;

comment on function public.enforce_staff_profile_mutation_boundary() is
  'Blocks direct authenticated role/is_active changes outside trusted RPCs. '
  'SECURITY DEFINER with empty search_path. service_role and '
  'app.trusted_staff_management=1 are allowed.';

revoke all on function public.enforce_staff_profile_mutation_boundary()
  from public, anon, authenticated;
grant execute on function public.enforce_staff_profile_mutation_boundary()
  to service_role;

create trigger profiles_enforce_staff_management_boundary
before update on public.profiles
for each row
execute function public.enforce_staff_profile_mutation_boundary();

-- ---------------------------------------------------------------------------
-- Admin-only cross-profile updates (replace staff-wide update policy)
-- ---------------------------------------------------------------------------
drop policy if exists profiles_staff_update on public.profiles;

create policy profiles_admin_update
  on public.profiles for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

comment on policy profiles_admin_update on public.profiles is
  'Only active admins may update other profiles. role/is_active still require '
  'update_cms_staff because of profiles_enforce_staff_management_boundary.';

-- ---------------------------------------------------------------------------
-- list_cms_staff
-- ---------------------------------------------------------------------------
create or replace function public.list_cms_staff(
  p_search text default '',
  p_role text default 'all',
  p_active text default 'all',
  p_sort text default 'name_asc',
  p_offset integer default 0,
  p_limit integer default 20
)
returns table (
  profile_id uuid,
  full_name text,
  email text,
  role text,
  is_active boolean,
  created_at timestamp with time zone,
  filtered_count integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_search_raw text;
  v_literal text;
  v_none_match boolean;
  v_role text;
  v_active text;
  v_sort text;
  v_offset integer;
  v_limit integer;
begin
  if not public.is_admin() then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  v_search_raw := pg_catalog.left(pg_catalog.btrim(coalesce(p_search, '')), 80);
  v_literal := pg_catalog.replace(
    pg_catalog.replace(
      pg_catalog.replace(v_search_raw, '\', ''),
      '%',
      ''
    ),
    '_',
    ''
  );
  v_none_match := v_search_raw <> '' and v_literal = '';

  v_role := coalesce(p_role, 'all');
  if v_role not in ('all', 'staff', 'admin') then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_active := coalesce(p_active, 'all');
  if v_active not in ('all', 'active', 'inactive') then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_sort := coalesce(p_sort, 'name_asc');
  if v_sort not in (
    'name_asc',
    'name_desc',
    'created_desc',
    'created_asc',
    'role_asc'
  ) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_offset is null or p_offset < 0 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;
  v_offset := p_offset;

  if p_limit is null or p_limit < 1 or p_limit > 50 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;
  v_limit := p_limit;

  return query
  with filtered as (
    select
      p.id as profile_id,
      p.full_name,
      u.email::text as email,
      p.role,
      p.is_active,
      p.created_at
    from public.profiles as p
    inner join auth.users as u
      on u.id = p.id
    where p.role in ('staff', 'admin')
      and (
        v_role = 'all'
        or p.role = v_role
      )
      and (
        v_active = 'all'
        or (v_active = 'active' and p.is_active = true)
        or (v_active = 'inactive' and p.is_active = false)
      )
      and (
        v_none_match
        or v_literal = ''
        or pg_catalog.lower(coalesce(p.full_name, '')) like
          '%' || pg_catalog.lower(v_literal) || '%'
        or pg_catalog.lower(u.email) like
          '%' || pg_catalog.lower(v_literal) || '%'
      )
  ),
  counted as (
    select count(*)::integer as filtered_count
    from filtered
  )
  select
    f.profile_id,
    f.full_name,
    f.email,
    f.role,
    f.is_active,
    f.created_at,
    c.filtered_count
  from filtered as f
  cross join counted as c
  order by
    case when v_sort = 'name_asc' then pg_catalog.lower(coalesce(f.full_name, f.email)) end asc,
    case when v_sort = 'name_desc' then pg_catalog.lower(coalesce(f.full_name, f.email)) end desc,
    case when v_sort = 'created_desc' then f.created_at end desc,
    case when v_sort = 'created_asc' then f.created_at end asc,
    case when v_sort = 'role_asc' then f.role end asc,
    f.profile_id asc
  offset v_offset
  limit v_limit;
end;
$$;

comment on function public.list_cms_staff(text, text, text, text, integer, integer) is
  'Admin-only staff/admin directory with bounded pagination/search. '
  'STABLE, SECURITY DEFINER, empty search_path. Returns PII-minimized fields '
  'only (no phone, avatar, or customer profiles). Authorizes via is_admin().';

revoke all on function public.list_cms_staff(text, text, text, text, integer, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.list_cms_staff(text, text, text, text, integer, integer)
  to authenticated;

-- ---------------------------------------------------------------------------
-- update_cms_staff
-- ---------------------------------------------------------------------------
create or replace function public.update_cms_staff(
  p_target_id uuid,
  p_role text default null,
  p_is_active boolean default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_target public.profiles%rowtype;
  v_next_role text;
  v_next_active boolean;
  v_active_admin_count integer;
  v_action text;
begin
  if not public.is_admin() then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  v_actor := auth.uid();
  if v_actor is null then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  if p_target_id is null then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_role is null and p_is_active is null then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_role is not null and p_role not in ('staff', 'admin') then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('cms_staff_last_admin_guard')
  );

  select *
  into v_target
  from public.profiles
  where id = p_target_id
  for update;

  if not found then
    raise exception 'not found'
      using errcode = 'P0002';
  end if;

  if v_target.role not in ('staff', 'admin') then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_next_role := coalesce(p_role, v_target.role);
  v_next_active := coalesce(p_is_active, v_target.is_active);

  if v_next_role = v_target.role and v_next_active = v_target.is_active then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if v_actor = p_target_id then
    if v_next_active = false then
      raise exception 'not authorized'
        using errcode = '42501';
    end if;

    if v_target.role = 'admin' and v_next_role = 'staff' then
      raise exception 'not authorized'
        using errcode = '42501';
    end if;
  end if;

  if v_target.role = 'admin'
     and v_target.is_active = true
     and (
       v_next_active = false
       or v_next_role = 'staff'
     ) then
    select count(*)::integer
    into v_active_admin_count
    from (
      select id
      from public.profiles
      where role = 'admin'
        and is_active = true
      for update
    ) as locked_admins;

    if v_active_admin_count <= 1 then
      raise exception 'not authorized'
        using errcode = '42501';
    end if;
  end if;

  perform set_config('app.trusted_staff_management', '1', true);

  update public.profiles as p
  set
    role = v_next_role,
    is_active = v_next_active
  where p.id = p_target_id;

  if v_next_active = true and v_target.is_active = false then
    v_action := 'activate';
  elsif v_next_active = false and v_target.is_active = true then
    v_action := 'deactivate';
  elsif v_next_role = 'admin' and v_target.role = 'staff' then
    v_action := 'promote';
  elsif v_next_role = 'staff' and v_target.role = 'admin' then
    v_action := 'demote';
  else
    v_action := 'activate';
  end if;

  insert into public.staff_management_events (
    actor_id,
    target_id,
    action,
    previous_role,
    new_role,
    previous_is_active,
    new_is_active
  ) values (
    v_actor,
    p_target_id,
    v_action,
    v_target.role,
    v_next_role,
    v_target.is_active,
    v_next_active
  );

  return p_target_id;
end;
$$;

comment on function public.update_cms_staff(uuid, text, boolean) is
  'Admin-only trusted staff/admin activation and role transitions. '
  'SECURITY DEFINER with empty search_path. Blocks self-deactivation/self-demotion '
  'and last-active-admin removal under concurrency via advisory lock + FOR UPDATE. '
  'Returns only target profile_id.';

revoke all on function public.update_cms_staff(uuid, text, boolean)
  from public, anon, authenticated, service_role;
grant execute on function public.update_cms_staff(uuid, text, boolean)
  to authenticated;
