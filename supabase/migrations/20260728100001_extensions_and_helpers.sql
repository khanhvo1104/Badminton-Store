-- Extensions and shared helpers for Badminton Store.

create extension if not exists "pgcrypto";

comment on extension pgcrypto is
  'Provides gen_random_uuid() for primary keys.';

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

comment on function public.set_updated_at() is
  'Sets NEW.updated_at to UTC now() on row update. SECURITY INVOKER.';

revoke all on function public.set_updated_at() from public;
grant execute on function public.set_updated_at() to authenticated, service_role;
