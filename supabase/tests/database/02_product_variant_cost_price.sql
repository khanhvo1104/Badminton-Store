-- Executable regression: product_variants.cost_price must not be readable by
-- public Data API roles (anon / authenticated). Safe mapper columns remain
-- readable for active product+variant rows; inactive / non-active-parent rows
-- stay hidden by existing RLS.
--
-- Run against an already migrated + seeded disposable local database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/02_product_variant_cost_price.sql
--
-- Do not insert, print, or return cost_price values.

\echo '== product_variants cost_price column privilege regression =='

do $$
declare
  safe_cols text[] := array[
    'id',
    'product_id',
    'sku',
    'name',
    'color_name',
    'color_hex',
    'racket_weight_class',
    'grip_size',
    'shoe_size',
    'clothing_size',
    'unit',
    'price',
    'compare_at_price',
    'attributes',
    'is_default',
    'is_active',
    'sort_order'
  ];
  col text;
  table_select_grantee text;
begin
  -- Table-wide SELECT would make every column selectable (including cost_price).
  for table_select_grantee in
    select grantee
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'product_variants'
      and privilege_type = 'SELECT'
      and grantee in ('anon', 'authenticated')
  loop
    raise exception
      'FAIL: % still has table-wide SELECT on product_variants',
      table_select_grantee;
  end loop;

  if has_column_privilege(
    'anon', 'public.product_variants', 'cost_price', 'SELECT'
  ) then
    raise exception 'FAIL: anon can SELECT product_variants.cost_price';
  end if;
  if has_column_privilege(
    'authenticated', 'public.product_variants', 'cost_price', 'SELECT'
  ) then
    raise exception
      'FAIL: authenticated can SELECT product_variants.cost_price';
  end if;

  if not has_column_privilege(
    'service_role', 'public.product_variants', 'cost_price', 'SELECT'
  ) then
    raise exception
      'FAIL: service_role lost SELECT on product_variants.cost_price';
  end if;

  if has_column_privilege(
    'anon', 'public.product_variants', 'barcode', 'SELECT'
  ) then
    raise exception 'FAIL: anon can SELECT product_variants.barcode';
  end if;
  if has_column_privilege(
    'authenticated', 'public.product_variants', 'barcode', 'SELECT'
  ) then
    raise exception
      'FAIL: authenticated can SELECT product_variants.barcode';
  end if;

  foreach col in array safe_cols loop
    if not has_column_privilege(
      'anon', 'public.product_variants', col, 'SELECT'
    ) then
      raise exception
        'FAIL: anon missing SELECT on product_variants.%', col;
    end if;
    if not has_column_privilege(
      'authenticated', 'public.product_variants', col, 'SELECT'
    ) then
      raise exception
        'FAIL: authenticated missing SELECT on product_variants.%', col;
    end if;
  end loop;

  raise notice 'OK: column privileges for anon/authenticated/service_role';
end $$;

-- Role-switched query assertions (transaction-local; isolated per scenario).
do $$
declare
  active_variant_id uuid := '40000000-0000-4000-8000-000000000001';
  inactive_variant_id uuid := '40000000-0000-4000-8000-000000000028';
  draft_parent_variant_id uuid := '40000000-0000-4000-8000-000000000017';
  visible_count integer;
  role_name text;
begin
  foreach role_name in array array['anon', 'authenticated'] loop
    begin
      execute format('set local role %I', role_name);

      begin
        execute
          'select cost_price from public.product_variants where id = $1'
          using active_variant_id;
        raise exception
          'FAIL: % SELECT cost_price unexpectedly succeeded', role_name;
      exception
        when insufficient_privilege then
          null; -- expected
        when others then
          raise exception
            'FAIL: % SELECT cost_price raised unexpected SQLSTATE %: %',
            role_name,
            sqlstate,
            sqlerrm;
      end;

      begin
        execute
          'select barcode from public.product_variants where id = $1'
          using active_variant_id;
        raise exception
          'FAIL: % SELECT barcode unexpectedly succeeded', role_name;
      exception
        when insufficient_privilege then
          null; -- expected
        when others then
          raise exception
            'FAIL: % SELECT barcode raised unexpected SQLSTATE %: %',
            role_name,
            sqlstate,
            sqlerrm;
      end;

      execute
        $q$
          select count(*)
          from (
            select
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
              attributes,
              is_default,
              is_active,
              sort_order
            from public.product_variants
            where id = $1
          ) safe_projection
        $q$
        into visible_count
        using active_variant_id;

      if visible_count <> 1 then
        raise exception
          'FAIL: % cannot read safe projection for active seeded variant (count=%)',
          role_name,
          visible_count;
      end if;

      execute
        'select count(*) from (select id from public.product_variants where id = $1) t'
        into visible_count
        using inactive_variant_id;
      if visible_count <> 0 then
        raise exception
          'FAIL: % can see inactive variant %',
          role_name,
          inactive_variant_id;
      end if;

      execute
        'select count(*) from (select id from public.product_variants where id = $1) t'
        into visible_count
        using draft_parent_variant_id;
      if visible_count <> 0 then
        raise exception
          'FAIL: % can see variant on non-active product %',
          role_name,
          draft_parent_variant_id;
      end if;

      reset role;
    exception
      when others then
        reset role;
        raise;
    end;
  end loop;

  raise notice 'OK: role-switched safe read / cost_price denial / RLS boundary';
end $$;

\echo '== done =='
