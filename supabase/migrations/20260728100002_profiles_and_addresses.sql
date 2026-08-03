-- Profiles (1:1 with auth.users) and shipping addresses.

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  phone_number text,
  avatar_path text,
  date_of_birth date,
  gender text,
  role text not null default 'customer'
    constraint profiles_role_check
      check (role in ('customer', 'staff', 'admin')),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint profiles_full_name_length_check
    check (full_name is null or char_length(full_name) between 1 and 120),
  constraint profiles_phone_length_check
    check (phone_number is null or char_length(phone_number) between 8 and 20),
  constraint profiles_gender_check
    check (gender is null or gender in ('male', 'female', 'other', 'unspecified'))
);

comment on table public.profiles is
  'Application profile for each auth.users row. Role is server-trusted only.';
comment on column public.profiles.avatar_path is
  'Storage object path in user-avatars bucket, not a permanent URL.';
comment on column public.profiles.role is
  'customer | staff | admin. Never writable by the owning customer via RLS.';

create index profiles_role_idx on public.profiles (role);
create index profiles_is_active_idx on public.profiles (is_active);

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Trusted role helpers (must exist after profiles)
-- ---------------------------------------------------------------------------
create or replace function public.is_staff_or_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_active = true
      and p.role in ('staff', 'admin')
  );
$$;

comment on function public.is_staff_or_admin() is
  'Returns true when auth.uid() maps to an active staff/admin profile. '
  'SECURITY DEFINER with fixed search_path; reads only public.profiles.role. '
  'Never trust a role claim from the Flutter request body.';

revoke all on function public.is_staff_or_admin() from public;
grant execute on function public.is_staff_or_admin() to authenticated, anon, service_role;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_active = true
      and p.role = 'admin'
  );
$$;

comment on function public.is_admin() is
  'True when the current user is an active admin. SECURITY DEFINER.';

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated, anon, service_role;

-- ---------------------------------------------------------------------------
-- Auto-create profile on auth signup (idempotent)
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role, is_active)
  values (
    new.id,
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), ''),
    'customer',
    true
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

comment on function public.handle_new_user_profile() is
  'Idempotent profile bootstrap after auth.users insert. SECURITY DEFINER. '
  'Always assigns role=customer; never copies tokens or secrets.';

revoke all on function public.handle_new_user_profile() from public;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user_profile();

-- Prevent customers from escalating role / deactivating themselves.
create or replace function public.prevent_profile_privilege_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null
     and auth.uid() = new.id
     and not public.is_staff_or_admin() then
    new.role := old.role;
    new.is_active := old.is_active;
  end if;
  return new;
end;
$$;

comment on function public.prevent_profile_privilege_escalation() is
  'Locks role and is_active for non-staff self-updates. SECURITY DEFINER.';

create trigger profiles_prevent_privilege_escalation
before update on public.profiles
for each row
execute function public.prevent_profile_privilege_escalation();

-- ---------------------------------------------------------------------------
-- addresses (Vietnam-oriented)
-- ---------------------------------------------------------------------------
create table public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  recipient_name text not null,
  phone_number text not null,
  province_code text,
  province_name text not null,
  district_code text,
  district_name text not null,
  ward_code text,
  ward_name text not null,
  street_address text not null,
  address_note text,
  is_default boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint addresses_recipient_name_check
    check (char_length(trim(recipient_name)) between 1 and 120),
  constraint addresses_phone_check
    check (char_length(trim(phone_number)) between 8 and 20),
  constraint addresses_province_name_check
    check (char_length(trim(province_name)) between 1 and 100),
  constraint addresses_district_name_check
    check (char_length(trim(district_name)) between 1 and 100),
  constraint addresses_ward_name_check
    check (char_length(trim(ward_name)) between 1 and 100),
  constraint addresses_street_check
    check (char_length(trim(street_address)) between 1 and 255)
);

comment on table public.addresses is
  'Customer shipping addresses. Exactly one default per user via partial unique index.';

create index addresses_user_id_idx on public.addresses (user_id);

create unique index addresses_one_default_per_user_idx
  on public.addresses (user_id)
  where is_default = true;

create trigger addresses_set_updated_at
before update on public.addresses
for each row
execute function public.set_updated_at();
