-- Order number generation and status-history trigger.

create or replace function public.generate_order_number()
returns text
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_date text := to_char(timezone('utc', now()), 'YYYYMMDD');
  v_suffix text;
  v_candidate text;
  v_attempts integer := 0;
begin
  loop
    v_attempts := v_attempts + 1;
    v_suffix := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    v_candidate := 'BDM-' || v_date || '-' || v_suffix;

    exit when not exists (
      select 1 from public.orders o where o.order_number = v_candidate
    );

    if v_attempts >= 20 then
      raise exception 'Unable to generate unique order_number after % attempts',
        v_attempts;
    end if;
  end loop;

  return v_candidate;
end;
$$;

comment on function public.generate_order_number() is
  'Concurrency-safe readable order number (BDM-YYYYMMDD-XXXXXX). '
  'UUID remains the true identifier. SECURITY DEFINER.';

revoke all on function public.generate_order_number() from public;
grant execute on function public.generate_order_number() to authenticated, service_role;

create or replace function public.assign_order_number()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.order_number is null or btrim(new.order_number) = '' then
    new.order_number := public.generate_order_number();
  end if;
  return new;
end;
$$;

comment on function public.assign_order_number() is
  'Assigns generate_order_number() when order_number is empty on insert.';

create trigger orders_assign_order_number
before insert on public.orders
for each row
execute function public.assign_order_number();

create or replace function public.record_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then
    return new;
  end if;

  insert into public.order_status_history (
    order_id,
    from_status,
    to_status,
    changed_by,
    note
  )
  values (
    new.id,
    case when tg_op = 'INSERT' then null else old.status end,
    new.status,
    auth.uid(),
    null
  );

  return new;
end;
$$;

comment on function public.record_order_status_change() is
  'Writes order_status_history only when status changes. SECURITY DEFINER.';

create trigger orders_record_status_history
after insert or update of status on public.orders
for each row
execute function public.record_order_status_change();
