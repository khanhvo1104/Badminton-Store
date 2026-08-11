-- TASK-026: least-privilege staff/admin RPC for variant cost prices.
--
-- authenticated intentionally lacks SELECT(cost_price) on product_variants
-- (customers share that PostgreSQL role). This SECURITY DEFINER RPC returns
-- only variant_id + cost_price for one explicitly requested product, after
-- validating the caller's trusted active profiles.role.
--
-- Does not alter tables, RLS policies, Storage policies, or column grants.

create or replace function public.get_staff_variant_costs(p_product_id uuid)
returns table (
  variant_id uuid,
  cost_price numeric(14, 2)
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_caller uuid;
begin
  if p_product_id is null then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_caller := auth.uid();

  if v_caller is null
     or not exists (
       select 1
       from public.profiles as profile_row
       where profile_row.id = v_caller
         and profile_row.is_active = true
         and profile_row.role in ('staff', 'admin')
     )
  then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  return query
  select
    variant_row.id,
    variant_row.cost_price
  from public.product_variants as variant_row
  where variant_row.product_id = p_product_id
  order by variant_row.sort_order asc, variant_row.id asc;
end;
$$;

comment on function public.get_staff_variant_costs(uuid) is
  'Returns variant_id and cost_price for one product. SECURITY DEFINER, '
  'STABLE, empty search_path. Authorizes only active trusted profiles.role '
  'staff/admin via auth.uid(). EXECUTE granted to authenticated only; '
  'callers without a trusted profile still fail. Does not grant table-wide '
  'or column SELECT(cost_price) to anon/authenticated.';

revoke all on function public.get_staff_variant_costs(uuid) from public;
revoke all on function public.get_staff_variant_costs(uuid) from anon;
revoke all on function public.get_staff_variant_costs(uuid) from authenticated;
revoke all on function public.get_staff_variant_costs(uuid) from service_role;

grant execute on function public.get_staff_variant_costs(uuid) to authenticated;
