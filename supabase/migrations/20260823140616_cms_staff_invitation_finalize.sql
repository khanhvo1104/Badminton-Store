-- TASK-041 review: trusted invitation finalization for PostgREST service_role JWT.
--
-- PostgREST uses session_user = authenticator even with a service-role JWT, so
-- direct profile UPDATE/audit from the Edge Function hits
-- enforce_staff_profile_mutation_boundary. Finalization goes through this
-- SECURITY DEFINER RPC (service_role EXECUTE only) which re-checks the actor
-- admin profile, validates target/email, sets the trusted GUC, updates exactly
-- one profile row, and inserts the audit event in one transaction.

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

  if session_user = 'postgres' then
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
  'Blocks direct role/is_active changes outside trusted RPCs. SECURITY DEFINER '
  'with empty search_path. postgres superuser fixtures and '
  'app.trusted_staff_management=1 (trusted RPCs) are allowed. PostgREST '
  'service-role JWTs use session_user authenticator and must not bypass.';

create or replace function public.finalize_cms_staff_invitation(
  p_actor_id uuid,
  p_target_id uuid,
  p_role text,
  p_target_email text,
  p_full_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor public.profiles%rowtype;
  v_target public.profiles%rowtype;
  v_auth_email text;
  v_full_name text;
begin
  if p_actor_id is null
     or p_target_id is null
     or p_role is null
     or p_target_email is null then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if p_role not in ('staff', 'admin') then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if char_length(trim(p_target_email)) < 3
     or char_length(p_target_email) > 254 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  select *
  into v_actor
  from public.profiles
  where id = p_actor_id;

  if not found
     or v_actor.role <> 'admin'
     or v_actor.is_active <> true then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  select u.email::text
  into v_auth_email
  from auth.users as u
  where u.id = p_target_id;

  if v_auth_email is null
     or lower(trim(v_auth_email)) <> lower(trim(p_target_email)) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  select *
  into v_target
  from public.profiles
  where id = p_target_id
  for update;

  if not found then
    raise exception 'not found'
      using errcode = 'P0002';
  end if;

  if v_target.role not in ('customer', 'staff', 'admin') then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_full_name := nullif(trim(coalesce(p_full_name, '')), '');
  if v_full_name is not null
     and char_length(v_full_name) > 120 then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  perform set_config('app.trusted_staff_management', '1', true);

  update public.profiles as p
  set
    role = p_role,
    is_active = true,
    full_name = coalesce(v_full_name, p.full_name)
  where p.id = p_target_id;

  if not found then
    raise exception 'not found'
      using errcode = 'P0002';
  end if;

  insert into public.staff_management_events (
    actor_id,
    target_id,
    action,
    previous_role,
    new_role,
    previous_is_active,
    new_is_active,
    target_email
  ) values (
    p_actor_id,
    p_target_id,
    'invite',
    v_target.role,
    p_role,
    v_target.is_active,
    true,
    lower(trim(p_target_email))
  );

  return p_target_id;
end;
$$;

comment on function public.finalize_cms_staff_invitation(uuid, uuid, text, text, text) is
  'Trusted Edge Function invitation finalization. SECURITY DEFINER with empty '
  'search_path. EXECUTE granted to service_role only. Re-checks active admin '
  'actor from public.profiles, validates target auth.users email, sets trusted '
  'GUC, updates exactly one profile, and inserts one audit row atomically. '
  'Returns target profile_id.';

revoke all on function public.finalize_cms_staff_invitation(uuid, uuid, text, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.finalize_cms_staff_invitation(uuid, uuid, text, text, text)
  to service_role;
