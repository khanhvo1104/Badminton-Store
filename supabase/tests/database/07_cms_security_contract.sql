-- Executable regression: CMS staff/admin variant cost RPC + focused catalog
-- and Storage authorization matrix (TASK-026).
--
-- Run against an already migrated + seeded disposable local database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/07_cms_security_contract.sql
--
-- Fixtures run inside a transaction and roll back. Assert only scenario
-- labels, IDs, counts, nullability, and SQLSTATEs — never print cost
-- values, JWTs, credentials, tokens, or caught internal error details.

\set ON_ERROR_STOP on
\echo '== CMS security contract regression (TASK-026) =='

begin;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function pg_temp.cms_insert_user(
  p_user_id uuid,
  p_email text
)
returns void
language plpgsql
as $$
begin
  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000',
    p_user_id,
    'authenticated',
    'authenticated',
    p_email,
    crypt('cms-test-password', gen_salt('bf')),
    timezone('utc', now()),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    timezone('utc', now()),
    timezone('utc', now())
  );
end;
$$;

create or replace function pg_temp.cms_set_auth(p_user_id uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', p_user_id::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', p_user_id::text,
      'role', 'authenticated'
    )::text,
    true
  );
  execute 'set local role authenticated';
end;
$$;

create or replace function pg_temp.cms_set_auth_forged_staff(p_user_id uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', p_user_id::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', p_user_id::text,
      'role', 'authenticated',
      'app_metadata', json_build_object('role', 'admin'),
      'user_metadata', json_build_object('role', 'staff')
    )::text,
    true
  );
  execute 'set local role authenticated';
end;
$$;

create or replace function pg_temp.cms_set_auth_no_uid()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('role', 'authenticated')::text,
    true
  );
  execute 'set local role authenticated';
end;
$$;

create or replace function pg_temp.cms_set_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('role', 'anon')::text,
    true
  );
  execute 'set local role anon';
end;
$$;

create or replace function pg_temp.cms_clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

create or replace function pg_temp.cms_assert_authz_denied(
  p_label text,
  p_sql text
)
returns void
language plpgsql
as $$
declare
  v_denied boolean := false;
begin
  begin
    execute p_sql;
  exception
    when insufficient_privilege then
      if sqlerrm = 'not authorized' then
        v_denied := true;
      else
        perform pg_temp.cms_clear_auth();
        raise exception
          'FAIL: % raised 42501 with unexpected message',
          p_label;
      end if;
    when others then
      if sqlstate = '42501' and sqlerrm = 'not authorized' then
        v_denied := true;
      else
        perform pg_temp.cms_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.cms_clear_auth();
    raise exception 'FAIL: % expected authorization denial', p_label;
  end if;
end;
$$;

create or replace function pg_temp.cms_assert_validation_denied(
  p_label text,
  p_sql text
)
returns void
language plpgsql
as $$
declare
  v_denied boolean := false;
begin
  begin
    execute p_sql;
  exception
    when others then
      if sqlstate = '22023' and sqlerrm = 'invalid request' then
        v_denied := true;
      else
        perform pg_temp.cms_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.cms_clear_auth();
    raise exception 'FAIL: % expected validation denial', p_label;
  end if;
end;
$$;

create or replace function pg_temp.cms_assert_execute_denied(
  p_label text,
  p_sql text
)
returns void
language plpgsql
as $$
declare
  v_denied boolean := false;
begin
  begin
    execute p_sql;
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate = '42501' then
        v_denied := true;
      else
        perform pg_temp.cms_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.cms_clear_auth();
    raise exception 'FAIL: % expected EXECUTE denial', p_label;
  end if;
end;
$$;

create or replace function pg_temp.cms_assert_mutation_denied(
  p_label text,
  p_sql text
)
returns void
language plpgsql
as $$
declare
  v_denied boolean := false;
  v_n integer;
begin
  begin
    execute p_sql;
    get diagnostics v_n = row_count;
    if v_n = 0 then
      v_denied := true;
    end if;
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate = '42501' then
        v_denied := true;
      else
        perform pg_temp.cms_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.cms_clear_auth();
    raise exception 'FAIL: % unexpectedly mutated rows', p_label;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Catalog: function definition + privilege + cost_price column matrix
-- ---------------------------------------------------------------------------
do $$
declare
  v_sig text := 'public.get_staff_variant_costs(uuid)';
  v_volatile "char";
  v_secdef boolean;
  v_config text[];
  v_in_names text[];
  v_out_names text[];
  v_out_types text[];
  v_grantee text;
begin
  select p.provolatile, p.prosecdef, p.proconfig
  into v_volatile, v_secdef, v_config
  from pg_proc p
  where p.oid = v_sig::regprocedure;

  if v_volatile is distinct from 's' then
    raise exception 'FAIL: get_staff_variant_costs is not STABLE';
  end if;
  if v_secdef is not true then
    raise exception 'FAIL: get_staff_variant_costs is not SECURITY DEFINER';
  end if;
  if v_config is null
     or not exists (
       select 1
       from unnest(v_config) as cfg(val)
       where cfg.val in ('search_path=', 'search_path=""')
     )
  then
    raise exception 'FAIL: get_staff_variant_costs search_path is not empty';
  end if;

  if pg_get_function_identity_arguments(v_sig::regprocedure)
     is distinct from 'p_product_id uuid'
  then
    raise exception 'FAIL: get_staff_variant_costs argument contract mismatch';
  end if;

  select
    coalesce(
      array_agg(x.argname order by x.ord) filter (where x.mode = 'i'),
      array[]::text[]
    ),
    coalesce(
      array_agg(x.argname order by x.ord) filter (where x.mode = 't'),
      array[]::text[]
    ),
    coalesce(
      array_agg(x.typ order by x.ord) filter (where x.mode = 't'),
      array[]::text[]
    )
  into v_in_names, v_out_names, v_out_types
  from (
    select
      t.ord,
      t.argname,
      t.mode,
      pg_catalog.format_type(t.argtype, null) as typ
    from (
      select
        ordinality as ord,
        argname,
        mode,
        argtype
      from pg_proc p
      cross join lateral unnest(
        p.proargnames,
        p.proargmodes,
        p.proallargtypes
      ) with ordinality as u(argname, mode, argtype, ordinality)
      where p.oid = v_sig::regprocedure
    ) as t
  ) as x;

  if v_in_names is distinct from array['p_product_id']::text[] then
    raise exception 'FAIL: get_staff_variant_costs IN argument names mismatch';
  end if;
  if v_out_names is distinct from array['variant_id', 'cost_price']::text[]
  then
    raise exception 'FAIL: get_staff_variant_costs return columns mismatch';
  end if;
  -- RETURNS TABLE OUT params are catalogued as plain numeric; values still
  -- come from product_variants.cost_price numeric(14,2).
  if v_out_types is distinct from array['uuid', 'numeric']::text[] then
    raise exception 'FAIL: get_staff_variant_costs return types mismatch';
  end if;

  if has_function_privilege('public', v_sig, 'EXECUTE') then
    raise exception 'FAIL: PUBLIC has EXECUTE on get_staff_variant_costs';
  end if;
  if has_function_privilege('anon', v_sig, 'EXECUTE') then
    raise exception 'FAIL: anon has EXECUTE on get_staff_variant_costs';
  end if;
  if has_function_privilege('service_role', v_sig, 'EXECUTE') then
    raise exception 'FAIL: service_role has EXECUTE on get_staff_variant_costs';
  end if;
  if not has_function_privilege('authenticated', v_sig, 'EXECUTE') then
    raise exception
      'FAIL: authenticated missing EXECUTE on get_staff_variant_costs';
  end if;

  for v_grantee in
    select grantee
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'product_variants'
      and privilege_type = 'SELECT'
      and grantee in ('anon', 'authenticated')
  loop
    raise exception
      'FAIL: % has table-wide SELECT on product_variants',
      v_grantee;
  end loop;

  foreach v_grantee in array array['anon', 'authenticated'] loop
    if has_column_privilege(
      v_grantee, 'public.product_variants', 'cost_price', 'SELECT'
    ) then
      raise exception
        'FAIL: % can SELECT product_variants.cost_price',
        v_grantee;
    end if;
  end loop;

  raise notice 'OK: RPC definition + EXECUTE + cost_price column matrix';
end $$;

-- ---------------------------------------------------------------------------
-- Fixtures (owner context; rolled back)
-- ---------------------------------------------------------------------------
select pg_temp.cms_insert_user(
  'a2600000-0000-4000-8000-000000000001',
  'cms-customer@example.invalid'
);
select pg_temp.cms_insert_user(
  'a2600000-0000-4000-8000-000000000002',
  'cms-staff@example.invalid'
);
select pg_temp.cms_insert_user(
  'a2600000-0000-4000-8000-000000000003',
  'cms-admin@example.invalid'
);
select pg_temp.cms_insert_user(
  'a2600000-0000-4000-8000-000000000004',
  'cms-inactive-staff@example.invalid'
);
select pg_temp.cms_insert_user(
  'a2600000-0000-4000-8000-000000000005',
  'cms-missing-profile@example.invalid'
);
select pg_temp.cms_insert_user(
  'a2600000-0000-4000-8000-000000000006',
  'cms-unsupported-role@example.invalid'
);
select pg_temp.cms_insert_user(
  'a2600000-0000-4000-8000-000000000007',
  'cms-forged@example.invalid'
);

update public.profiles
set role = 'staff', full_name = 'CMS Staff', is_active = true
where id = 'a2600000-0000-4000-8000-000000000002';

update public.profiles
set role = 'admin', full_name = 'CMS Admin', is_active = true
where id = 'a2600000-0000-4000-8000-000000000003';

update public.profiles
set role = 'staff', full_name = 'CMS Inactive Staff', is_active = false
where id = 'a2600000-0000-4000-8000-000000000004';

update public.profiles
set full_name = 'CMS Customer', is_active = true
where id = 'a2600000-0000-4000-8000-000000000001';

update public.profiles
set full_name = 'CMS Forged Customer', is_active = true
where id = 'a2600000-0000-4000-8000-000000000007';

-- Missing-profile fixture: auth subject exists, trusted profile row does not.
delete from public.profiles
where id = 'a2600000-0000-4000-8000-000000000005';

-- Unsupported trusted-profile role requires relaxing the production check
-- inside this rollback transaction only.
alter table public.profiles drop constraint profiles_role_check;

update public.profiles
set role = 'manager', full_name = 'CMS Unsupported Role', is_active = true
where id = 'a2600000-0000-4000-8000-000000000006';

insert into public.categories (id, name, slug, sort_order, is_active)
values (
  'a2610000-0000-4000-8000-000000000001',
  'CMS Contract Category',
  'cms-contract-category',
  260,
  true
);

insert into public.brands (id, name, slug, sort_order, is_active)
values (
  'a2611000-0000-4000-8000-000000000001',
  'CMS Contract Brand',
  'cms-contract-brand',
  260,
  true
);

insert into public.products (
  id, category_id, brand_id, name, slug, status, is_featured, published_at
) values
  (
    'a2620000-0000-4000-8000-000000000001',
    'a2610000-0000-4000-8000-000000000001',
    'a2611000-0000-4000-8000-000000000001',
    'CMS Contract Product A',
    'cms-contract-product-a',
    'active',
    false,
    timezone('utc', now())
  ),
  (
    'a2620000-0000-4000-8000-000000000002',
    'a2610000-0000-4000-8000-000000000001',
    'a2611000-0000-4000-8000-000000000001',
    'CMS Contract Product B',
    'cms-contract-product-b',
    'draft',
    false,
    null
  );

-- Product A variants: deterministic sort_order, id order including a tie.
-- Include inactive + null cost_price; no status filtering by the RPC.
insert into public.product_variants (
  id, product_id, sku, name, price, cost_price, is_active, is_default, sort_order
) values
  (
    'a2630000-0000-4000-8000-000000000001',
    'a2620000-0000-4000-8000-000000000001',
    'CMS-COST-A-S0',
    'A sort 0',
    100000,
    40000,
    true,
    true,
    0
  ),
  (
    'a2630000-0000-4000-8000-000000000002',
    'a2620000-0000-4000-8000-000000000001',
    'CMS-COST-A-S1-LOW',
    'A sort 1 low id',
    110000,
    null,
    true,
    false,
    1
  ),
  (
    'a2630000-0000-4000-8000-000000000003',
    'a2620000-0000-4000-8000-000000000001',
    'CMS-COST-A-S1-HIGH',
    'A sort 1 high id',
    120000,
    55000,
    false,
    false,
    1
  ),
  (
    'a2630000-0000-4000-8000-000000000004',
    'a2620000-0000-4000-8000-000000000001',
    'CMS-COST-A-S2',
    'A sort 2',
    130000,
    60000,
    true,
    false,
    2
  ),
  (
    'a2630000-0000-4000-8000-000000000010',
    'a2620000-0000-4000-8000-000000000002',
    'CMS-COST-B-1',
    'B only',
    90000,
    30000,
    true,
    true,
    0
  );

insert into storage.objects (id, bucket_id, name, metadata) values
  (
    'a2690000-0000-4000-8000-000000000001',
    'product-images',
    'cms-task026/product.webp',
    '{"mimetype":"image/webp","size":16}'::jsonb
  ),
  (
    'a2690000-0000-4000-8000-000000000002',
    'product-images',
    'cms-task026/staff-target.webp',
    '{"mimetype":"image/webp","size":16}'::jsonb
  );

-- ---------------------------------------------------------------------------
-- Direct cost_price denial for public API roles
-- ---------------------------------------------------------------------------
do $$
declare
  v_variant uuid := 'a2630000-0000-4000-8000-000000000001';
  v_role text;
  v_denied boolean;
begin
  foreach v_role in array array['anon', 'authenticated'] loop
    begin
      execute format('set local role %I', v_role);
      v_denied := false;
      begin
        execute
          'select cost_price from public.product_variants where id = $1'
          using v_variant;
      exception
        when insufficient_privilege then
          v_denied := true;
        when others then
          if sqlstate = '42501' then
            v_denied := true;
          else
            execute 'reset role';
            raise exception
              'FAIL: % SELECT cost_price unexpected SQLSTATE %',
              v_role,
              sqlstate;
          end if;
      end;
      execute 'reset role';
      if not v_denied then
        raise exception 'FAIL: % SELECT cost_price unexpectedly succeeded', v_role;
      end if;
    exception
      when others then
        execute 'reset role';
        raise;
    end;
  end loop;

  raise notice 'OK: anon/authenticated direct cost_price SELECT denied';
end $$;

-- ---------------------------------------------------------------------------
-- RPC denial matrix
-- ---------------------------------------------------------------------------
do $$
declare
  v_product_a uuid := 'a2620000-0000-4000-8000-000000000001';
  v_call text := format(
    'select variant_id from public.get_staff_variant_costs(%L::uuid)',
    'a2620000-0000-4000-8000-000000000001'
  );
begin
  perform pg_temp.cms_set_anon();
  perform pg_temp.cms_assert_execute_denied('anon RPC EXECUTE', v_call);
  perform pg_temp.cms_clear_auth();

  perform pg_temp.cms_set_auth_no_uid();
  perform pg_temp.cms_assert_authz_denied('null-subject RPC', v_call);
  perform pg_temp.cms_clear_auth();

  perform pg_temp.cms_set_auth('a2600000-0000-4000-8000-000000000001');
  perform pg_temp.cms_assert_authz_denied('customer RPC', v_call);
  perform pg_temp.cms_clear_auth();

  perform pg_temp.cms_set_auth('a2600000-0000-4000-8000-000000000004');
  perform pg_temp.cms_assert_authz_denied('inactive staff RPC', v_call);
  perform pg_temp.cms_clear_auth();

  perform pg_temp.cms_set_auth('a2600000-0000-4000-8000-000000000005');
  perform pg_temp.cms_assert_authz_denied('missing profile RPC', v_call);
  perform pg_temp.cms_clear_auth();

  perform pg_temp.cms_set_auth('a2600000-0000-4000-8000-000000000006');
  perform pg_temp.cms_assert_authz_denied('unsupported role RPC', v_call);
  perform pg_temp.cms_clear_auth();

  perform pg_temp.cms_set_auth_forged_staff(
    'a2600000-0000-4000-8000-000000000007'
  );
  perform pg_temp.cms_assert_authz_denied('forged metadata RPC', v_call);
  perform pg_temp.cms_clear_auth();

  -- service_role lacks EXECUTE (direct table access remains separate).
  begin
    execute 'set local role service_role';
    perform pg_temp.cms_assert_execute_denied(
      'service_role RPC EXECUTE',
      v_call
    );
    execute 'reset role';
  exception
    when others then
      execute 'reset role';
      raise;
  end;

  raise notice 'OK: RPC denial matrix';
exception
  when others then
    perform pg_temp.cms_clear_auth();
    raise;
end $$;

-- ---------------------------------------------------------------------------
-- Active staff / admin success: scope, order, nullability, two-column shape
-- ---------------------------------------------------------------------------
do $$
declare
  v_product_a uuid := 'a2620000-0000-4000-8000-000000000001';
  v_product_b uuid := 'a2620000-0000-4000-8000-000000000002';
  v_expected uuid[] := array[
    'a2630000-0000-4000-8000-000000000001'::uuid,
    'a2630000-0000-4000-8000-000000000002'::uuid,
    'a2630000-0000-4000-8000-000000000003'::uuid,
    'a2630000-0000-4000-8000-000000000004'::uuid
  ];
  v_ids uuid[];
  v_null_flags boolean[];
  v_actor uuid;
  v_missing_product_count integer;
begin
  foreach v_actor in array array[
    'a2600000-0000-4000-8000-000000000002'::uuid,
    'a2600000-0000-4000-8000-000000000003'::uuid
  ] loop
    perform pg_temp.cms_set_auth(v_actor);

    select
      coalesce(array_agg(r.variant_id order by r.ord), array[]::uuid[]),
      coalesce(array_agg(r.is_null_cost order by r.ord), array[]::boolean[])
    into v_ids, v_null_flags
    from (
      select
        q.variant_id,
        (q.cost_price is null) as is_null_cost,
        row_number() over () as ord
      from public.get_staff_variant_costs(v_product_a) as q
    ) as r;

    if v_ids is distinct from v_expected then
      perform pg_temp.cms_clear_auth();
      raise exception
        'FAIL: actor % returned unexpected variant id order/scope',
        v_actor;
    end if;

    if v_null_flags is distinct from array[false, true, false, false]
    then
      perform pg_temp.cms_clear_auth();
      raise exception
        'FAIL: actor % returned unexpected cost nullability pattern',
        v_actor;
    end if;

    -- Exact product scoping: product B must not appear in product A results.
    if exists (
      select 1
      from unnest(v_ids) as id(val)
      where id.val = 'a2630000-0000-4000-8000-000000000010'
    ) then
      perform pg_temp.cms_clear_auth();
      raise exception 'FAIL: actor % leaked product B variant', v_actor;
    end if;

    select coalesce(array_agg(q.variant_id order by q.ord), array[]::uuid[])
    into v_ids
    from (
      select
        r.variant_id,
        row_number() over () as ord
      from public.get_staff_variant_costs(v_product_b) as r
    ) as q;

    if v_ids is distinct from array[
      'a2630000-0000-4000-8000-000000000010'::uuid
    ] then
      perform pg_temp.cms_clear_auth();
      raise exception
        'FAIL: actor % product B scope/order mismatch',
        v_actor;
    end if;

    -- Missing product: authorized call returns zero rows (no leak).
    select count(*)::integer
    into v_missing_product_count
    from public.get_staff_variant_costs(
      'a2620000-0000-4000-8000-000000009999'::uuid
    );
    if v_missing_product_count <> 0 then
      perform pg_temp.cms_clear_auth();
      raise exception
        'FAIL: actor % missing product returned rows',
        v_actor;
    end if;

    perform pg_temp.cms_assert_validation_denied(
      format('actor %s null product', v_actor),
      'select variant_id from public.get_staff_variant_costs(null)'
    );

    perform pg_temp.cms_clear_auth();
  end loop;

  raise notice 'OK: staff/admin RPC success, scope, order, validation';
exception
  when others then
    perform pg_temp.cms_clear_auth();
    raise;
end $$;

-- ---------------------------------------------------------------------------
-- Focused CMS catalog + Storage authorization matrix
-- ---------------------------------------------------------------------------
do $$
declare
  v_customer uuid := 'a2600000-0000-4000-8000-000000000001';
  v_staff uuid := 'a2600000-0000-4000-8000-000000000002';
  v_admin uuid := 'a2600000-0000-4000-8000-000000000003';
  v_cat uuid := 'a2610000-0000-4000-8000-000000000001';
  v_staff_cat uuid := 'a2610000-0000-4000-8000-000000000010';
  v_admin_cat uuid := 'a2610000-0000-4000-8000-000000000011';
  v_staff_product uuid := 'a2620000-0000-4000-8000-000000000010';
  v_staff_variant uuid := 'a2630000-0000-4000-8000-000000000020';
  v_storage_target uuid := 'a2690000-0000-4000-8000-000000000002';
  v_staff_obj uuid := 'a2690000-0000-4000-8000-000000000010';
  v_admin_obj uuid := 'a2690000-0000-4000-8000-000000000011';
  v_count integer;
  v_meta jsonb;
begin
  -- Customer catalog / Storage mutations denied.
  perform pg_temp.cms_set_auth(v_customer);

  perform pg_temp.cms_assert_mutation_denied(
    'customer category INSERT',
    $q$insert into public.categories (name, slug, sort_order)
       values ('CMS Customer Cat', 'cms-customer-cat', 1)$q$
  );
  perform pg_temp.cms_assert_mutation_denied(
    'customer category UPDATE',
    format(
      $q$update public.categories set description = 'x' where id = %L$q$,
      v_cat
    )
  );
  perform pg_temp.cms_assert_mutation_denied(
    'customer category DELETE',
    format($q$delete from public.categories where id = %L$q$, v_cat)
  );
  perform pg_temp.cms_assert_mutation_denied(
    'customer product INSERT',
    format(
      $q$insert into public.products (
           category_id, brand_id, name, slug, status
         ) values (
           %L, 'a2611000-0000-4000-8000-000000000001',
           'CMS Customer Product', 'cms-customer-product', 'draft'
         )$q$,
      v_cat
    )
  );
  perform pg_temp.cms_assert_mutation_denied(
    'customer variant UPDATE',
    $q$update public.product_variants
       set name = 'hacked'
       where id = 'a2630000-0000-4000-8000-000000000001'$q$
  );
  perform pg_temp.cms_assert_mutation_denied(
    'customer storage catalog INSERT',
    $q$insert into storage.objects (bucket_id, name)
       values ('product-images', 'cms-task026/customer.webp')$q$
  );
  perform pg_temp.cms_assert_mutation_denied(
    'customer storage catalog UPDATE',
    format(
      $q$update storage.objects
         set metadata = '{"mimetype":"image/webp","size":1}'::jsonb
         where id = %L$q$,
      v_storage_target
    )
  );
  perform pg_temp.cms_assert_mutation_denied(
    'customer storage catalog DELETE',
    format($q$delete from storage.objects where id = %L$q$, v_storage_target)
  );

  perform pg_temp.cms_clear_auth();

  select count(*) into v_count
  from public.categories
  where id = v_cat;
  if v_count <> 1 then
    raise exception 'FAIL: customer catalog mutation altered category fixture';
  end if;

  select metadata into v_meta
  from storage.objects
  where id = v_storage_target;
  if v_meta is distinct from '{"mimetype":"image/webp","size":16}'::jsonb then
    raise exception 'FAIL: customer mutated catalog Storage object';
  end if;

  -- Active staff retains scoped catalog + catalog-bucket Storage capability.
  perform pg_temp.cms_set_auth(v_staff);
  -- Local Storage regressions exercise DELETE via SQL; unlock the guard used
  -- by supabase_storage (same pattern as 01_rls_checklist.sql).
  perform set_config('storage.allow_delete_query', 'true', true);

  insert into public.categories (id, name, slug, sort_order, is_active)
  values (v_staff_cat, 'CMS Staff Cat', 'cms-staff-cat', 261, true);

  update public.categories
  set description = 'staff-updated'
  where id = v_staff_cat;
  if not found then
    raise exception 'FAIL: staff cannot UPDATE category';
  end if;

  insert into public.products (
    id, category_id, brand_id, name, slug, status, is_featured, published_at
  ) values (
    v_staff_product,
    v_cat,
    'a2611000-0000-4000-8000-000000000001',
    'CMS Staff Product',
    'cms-staff-product',
    'draft',
    false,
    null
  );

  insert into public.product_variants (
    id, product_id, sku, name, price, is_active, is_default, sort_order
  ) values (
    v_staff_variant,
    v_staff_product,
    'CMS-STAFF-VAR',
    'Staff Variant',
    150000,
    true,
    true,
    0
  );

  update public.product_variants
  set name = 'Staff Variant Updated'
  where id = v_staff_variant;
  if not found then
    raise exception 'FAIL: staff cannot UPDATE variant';
  end if;

  insert into storage.objects (id, bucket_id, name, metadata)
  values (
    v_staff_obj,
    'product-images',
    'cms-task026/staff-upload.webp',
    '{"mimetype":"image/webp","size":8}'::jsonb
  );

  update storage.objects
  set metadata = '{"mimetype":"image/webp","size":9}'::jsonb
  where id = v_storage_target;
  if not found then
    raise exception 'FAIL: staff cannot UPDATE catalog Storage object';
  end if;

  delete from storage.objects where id = v_staff_obj;
  if not found then
    raise exception 'FAIL: staff cannot DELETE catalog Storage object';
  end if;

  delete from public.product_variants where id = v_staff_variant;
  if not found then
    raise exception 'FAIL: staff cannot DELETE variant';
  end if;

  delete from public.products where id = v_staff_product;
  if not found then
    raise exception 'FAIL: staff cannot DELETE product';
  end if;

  delete from public.categories where id = v_staff_cat;
  if not found then
    raise exception 'FAIL: staff cannot DELETE category';
  end if;

  perform pg_temp.cms_clear_auth();

  -- Active admin retains the same scoped capabilities.
  perform pg_temp.cms_set_auth(v_admin);

  insert into public.categories (id, name, slug, sort_order, is_active)
  values (v_admin_cat, 'CMS Admin Cat', 'cms-admin-cat', 262, true);

  update public.categories
  set description = 'admin-updated'
  where id = v_admin_cat;
  if not found then
    raise exception 'FAIL: admin cannot UPDATE category';
  end if;

  insert into storage.objects (id, bucket_id, name, metadata)
  values (
    v_admin_obj,
    'product-images',
    'cms-task026/admin-upload.webp',
    '{"mimetype":"image/webp","size":8}'::jsonb
  );

  update storage.objects
  set metadata = '{"mimetype":"image/webp","size":10}'::jsonb
  where id = v_storage_target;
  if not found then
    raise exception 'FAIL: admin cannot UPDATE catalog Storage object';
  end if;

  delete from storage.objects where id = v_admin_obj;
  if not found then
    raise exception 'FAIL: admin cannot DELETE catalog Storage object';
  end if;

  delete from public.categories where id = v_admin_cat;
  if not found then
    raise exception 'FAIL: admin cannot DELETE category';
  end if;

  perform pg_temp.cms_clear_auth();

  raise notice 'OK: CMS catalog/Storage authorization matrix';
exception
  when others then
    perform pg_temp.cms_clear_auth();
    raise;
end $$;

-- ---------------------------------------------------------------------------
-- list_cms_products: definition, grants, denial, count, and sort/filter pages
-- ---------------------------------------------------------------------------
do $$
declare
  v_sig text :=
    'public.list_cms_products(text, uuid, uuid, text, text, text, integer, integer)';
  v_volatile "char";
  v_secdef boolean;
  v_config text[];
  v_out_names text[];
  v_call text :=
    'select id from public.list_cms_products('''', null, null, null, ''all'', ''updated_desc'', 0, 20)';
  v_protected text[] := array[
    'cost_price', 'barcode', 'email', 'user_id', 'phone_number',
    'quantity_on_hand', 'quantity_reserved', 'reorder_level'
  ];
begin
  select p.provolatile, p.prosecdef, p.proconfig
  into v_volatile, v_secdef, v_config
  from pg_proc p
  where p.oid = v_sig::regprocedure;

  if v_volatile is distinct from 's' then
    raise exception 'FAIL: list_cms_products is not STABLE';
  end if;
  if v_secdef is not false then
    raise exception 'FAIL: list_cms_products is not SECURITY INVOKER';
  end if;
  if v_config is null
     or not exists (
       select 1
       from unnest(v_config) as cfg(val)
       where cfg.val in ('search_path=', 'search_path=""')
     )
  then
    raise exception 'FAIL: list_cms_products search_path is not empty';
  end if;

  select coalesce(
    array_agg(x.argname order by x.ord) filter (where x.mode = 't'),
    array[]::text[]
  )
  into v_out_names
  from (
    select t.ord, t.argname, t.mode
    from (
      select
        ordinality as ord,
        argname,
        mode
      from pg_proc p
      cross join lateral unnest(
        p.proargnames,
        p.proargmodes
      ) with ordinality as u(argname, mode, ordinality)
      where p.oid = v_sig::regprocedure
    ) as t
  ) as x;

  if v_out_names && v_protected then
    raise exception 'FAIL: list_cms_products return columns include protected names';
  end if;
  if not ('filtered_count' = any (v_out_names)) then
    raise exception 'FAIL: list_cms_products missing filtered_count';
  end if;

  if has_function_privilege('public', v_sig, 'EXECUTE') then
    raise exception 'FAIL: PUBLIC has EXECUTE on list_cms_products';
  end if;
  if has_function_privilege('anon', v_sig, 'EXECUTE') then
    raise exception 'FAIL: anon has EXECUTE on list_cms_products';
  end if;
  if not has_function_privilege('authenticated', v_sig, 'EXECUTE') then
    raise exception 'FAIL: authenticated missing EXECUTE on list_cms_products';
  end if;
  if not has_function_privilege('service_role', v_sig, 'EXECUTE') then
    raise exception 'FAIL: service_role missing EXECUTE on list_cms_products';
  end if;

  perform pg_temp.cms_set_anon();
  perform pg_temp.cms_assert_execute_denied('anon list_cms_products EXECUTE', v_call);
  perform pg_temp.cms_clear_auth();

  perform pg_temp.cms_set_auth('a2600000-0000-4000-8000-000000000001');
  perform pg_temp.cms_assert_authz_denied('customer list_cms_products', v_call);
  perform pg_temp.cms_clear_auth();

  perform pg_temp.cms_set_auth('a2600000-0000-4000-8000-000000000004');
  perform pg_temp.cms_assert_authz_denied('inactive staff list_cms_products', v_call);
  perform pg_temp.cms_clear_auth();

  perform pg_temp.cms_set_auth_forged_staff(
    'a2600000-0000-4000-8000-000000000007'
  );
  perform pg_temp.cms_assert_authz_denied('forged metadata list_cms_products', v_call);
  perform pg_temp.cms_clear_auth();

  raise notice 'OK: list_cms_products definition + denial matrix';
end $$;

do $$
declare
  v_category uuid := 'a2640000-0000-4000-8000-000000000001';
  v_p_low uuid := 'a2641000-0000-4000-8000-000000000001';
  v_p_mid uuid := 'a2641000-0000-4000-8000-000000000002';
  v_p_high uuid := 'a2641000-0000-4000-8000-000000000003';
  v_p_none uuid := 'a2641000-0000-4000-8000-000000000004';
  v_p_miss uuid := 'a2641000-0000-4000-8000-000000000005';
  v_ids uuid[];
  v_count integer;
  v_actor uuid;
  v_page1 uuid[];
  v_page2 uuid[];
begin
  insert into public.categories (id, name, slug, sort_order, is_active)
  values (v_category, 'CMS Explorer Category', 'cms-explorer-category', 264, true);

  insert into public.products (
    id, category_id, name, slug, status, is_featured, published_at
  ) values
    (v_p_low, v_category, 'Explorer Low', 'explorer-low', 'active', false, timezone('utc', now())),
    (v_p_mid, v_category, 'Explorer Mid', 'explorer-mid', 'active', false, timezone('utc', now())),
    (v_p_high, v_category, 'Explorer High', 'explorer-high', 'active', false, timezone('utc', now())),
    (v_p_none, v_category, 'Explorer None', 'explorer-none', 'draft', false, null),
    (v_p_miss, v_category, 'Explorer Missing', 'explorer-missing', 'inactive', false, null);

  insert into public.product_variants (
    id, product_id, sku, price, is_active, is_default, sort_order
  ) values
    ('a2642000-0000-4000-8000-000000000001', v_p_low, 'CMS-EXP-LOW', 50, true, true, 0),
    ('a2642000-0000-4000-8000-000000000002', v_p_mid, 'CMS-EXP-MID', 100, true, true, 0),
    ('a2642000-0000-4000-8000-000000000003', v_p_high, 'CMS-EXP-HIGH', 200, true, true, 0),
    ('a2642000-0000-4000-8000-000000000004', v_p_miss, 'CMS-EXP-MISS', 150, true, true, 0);

  insert into public.inventory (
    variant_id, quantity_on_hand, quantity_reserved, reorder_level
  ) values
    ('a2642000-0000-4000-8000-000000000001', 0, 0, 2),
    ('a2642000-0000-4000-8000-000000000002', 3, 0, 5),
    ('a2642000-0000-4000-8000-000000000003', 10, 0, 2);

  foreach v_actor in array array[
    'a2600000-0000-4000-8000-000000000002'::uuid,
    'a2600000-0000-4000-8000-000000000003'::uuid
  ] loop
    perform pg_temp.cms_set_auth(v_actor);

    select coalesce(array_agg(r.id order by r.ord), array[]::uuid[]), max(r.filtered_count)
    into v_ids, v_count
    from (
      select q.id, q.filtered_count, row_number() over () as ord
      from public.list_cms_products(
        '', v_category, null, null, 'all', 'price_asc', 0, 50
      ) as q
      where q.id is not null
    ) as r;

    if v_count is distinct from 5 then
      perform pg_temp.cms_clear_auth();
      raise exception 'FAIL: actor % exact filtered count was not 5', v_actor;
    end if;
    if v_ids is distinct from array[v_p_low, v_p_mid, v_p_miss, v_p_high, v_p_none]
    then
      perform pg_temp.cms_clear_auth();
      raise exception 'FAIL: actor % price_asc order mismatch', v_actor;
    end if;

    select coalesce(array_agg(r.id order by r.ord), array[]::uuid[])
    into v_page1
    from (
      select q.id, row_number() over () as ord
      from public.list_cms_products(
        '', v_category, null, null, 'all', 'price_asc', 0, 2
      ) as q
      where q.id is not null
    ) as r;

    select coalesce(array_agg(r.id order by r.ord), array[]::uuid[]), max(r.filtered_count)
    into v_page2, v_count
    from (
      select q.id, q.filtered_count, row_number() over () as ord
      from public.list_cms_products(
        '', v_category, null, null, 'all', 'price_asc', 2, 2
      ) as q
      where q.id is not null
    ) as r;

    if v_page1 is distinct from array[v_p_low, v_p_mid]
      or v_page2 is distinct from array[v_p_miss, v_p_high]
      or v_count is distinct from 5
    then
      perform pg_temp.cms_clear_auth();
      raise exception 'FAIL: actor % cross-page price order mismatch', v_actor;
    end if;

    select coalesce(array_agg(r.id order by r.ord), array[]::uuid[]), max(r.filtered_count)
    into v_ids, v_count
    from (
      select q.id, q.filtered_count, row_number() over () as ord
      from public.list_cms_products(
        '', v_category, null, null, 'in_stock', 'price_asc', 0, 1
      ) as q
      where q.id is not null
    ) as r;
    if v_ids is distinct from array[v_p_mid] or v_count is distinct from 2 then
      perform pg_temp.cms_clear_auth();
      raise exception 'FAIL: actor % in_stock page 1 mismatch', v_actor;
    end if;

    select coalesce(array_agg(r.id order by r.ord), array[]::uuid[]), max(r.filtered_count)
    into v_ids, v_count
    from (
      select q.id, q.filtered_count, row_number() over () as ord
      from public.list_cms_products(
        '', v_category, null, null, 'in_stock', 'price_asc', 1, 1
      ) as q
      where q.id is not null
    ) as r;
    if v_ids is distinct from array[v_p_high] or v_count is distinct from 2 then
      perform pg_temp.cms_clear_auth();
      raise exception 'FAIL: actor % in_stock page 2 mismatch', v_actor;
    end if;

    select max(q.filtered_count) into v_count
    from public.list_cms_products(
      '', v_category, null, null, 'missing', 'updated_desc', 0, 20
    ) as q;
    if v_count is distinct from 1 then
      perform pg_temp.cms_clear_auth();
      raise exception 'FAIL: actor % missing stock count mismatch', v_actor;
    end if;

    if exists (
      select 1
      from public.list_cms_products(
        '*),status.eq.active', v_category, null, null, 'all', 'updated_desc', 0, 20
      ) as q
      where q.id is not null
    ) then
      perform pg_temp.cms_clear_auth();
      raise exception 'FAIL: actor % search operators altered the filter', v_actor;
    end if;

    perform pg_temp.cms_clear_auth();
  end loop;

  raise notice 'OK: list_cms_products staff/admin count and cross-page order';
exception
  when others then
    perform pg_temp.cms_clear_auth();
    raise;
end $$;

-- ---------------------------------------------------------------------------
-- save_cms_product_variant: definition, grants, denial, return contract
-- ---------------------------------------------------------------------------
do $$
declare
  v_sig text :=
    'public.save_cms_product_variant(uuid, uuid, text, text, text, text, text, text, text, text, text, numeric, numeric, text, numeric, text, text, jsonb, boolean, boolean, integer)';
  v_volatile "char";
  v_secdef boolean;
  v_config text[];
  v_in_names text[];
  v_out_names text[];
  v_out_types text[];
  v_call text;
  v_actor uuid;
  v_returned jsonb;
  v_id uuid;
begin
  select p.provolatile, p.prosecdef, p.proconfig
  into v_volatile, v_secdef, v_config
  from pg_proc p
  where p.oid = v_sig::regprocedure;

  if v_volatile is distinct from 'v' then
    raise exception 'FAIL: save_cms_product_variant is not VOLATILE';
  end if;
  if v_secdef is not false then
    raise exception 'FAIL: save_cms_product_variant is not SECURITY INVOKER';
  end if;
  if v_config is null
     or not exists (
       select 1
       from unnest(v_config) as cfg(val)
       where cfg.val in ('search_path=', 'search_path=""')
     )
  then
    raise exception 'FAIL: save_cms_product_variant search_path is not empty';
  end if;

  select
    coalesce(
      array_agg(x.argname order by x.ord) filter (where x.mode = 'i'),
      array[]::text[]
    ),
    coalesce(
      array_agg(x.argname order by x.ord) filter (where x.mode = 't'),
      array[]::text[]
    ),
    coalesce(
      array_agg(x.typ order by x.ord) filter (where x.mode = 't'),
      array[]::text[]
    )
  into v_in_names, v_out_names, v_out_types
  from (
    select
      t.ord,
      t.argname,
      t.mode,
      pg_catalog.format_type(t.argtype, null) as typ
    from (
      select
        ordinality as ord,
        argname,
        mode,
        argtype
      from pg_proc p
      cross join lateral unnest(
        p.proargnames,
        p.proargmodes,
        p.proallargtypes
      ) with ordinality as u(argname, mode, argtype, ordinality)
      where p.oid = v_sig::regprocedure
    ) as t
  ) as x;

  if v_in_names is distinct from array[
    'p_product_id',
    'p_variant_id',
    'p_sku',
    'p_name',
    'p_color_name',
    'p_color_hex',
    'p_racket_weight_class',
    'p_grip_size',
    'p_shoe_size',
    'p_clothing_size',
    'p_unit',
    'p_price',
    'p_compare_at_price',
    'p_cost_mode',
    'p_cost_price',
    'p_barcode_mode',
    'p_barcode',
    'p_attributes',
    'p_is_default',
    'p_is_active',
    'p_sort_order'
  ]::text[] then
    raise exception 'FAIL: save_cms_product_variant IN argument names mismatch';
  end if;
  if v_out_names is distinct from array['variant_id']::text[] then
    raise exception 'FAIL: save_cms_product_variant return columns mismatch';
  end if;
  if v_out_types is distinct from array['uuid']::text[] then
    raise exception 'FAIL: save_cms_product_variant return types mismatch';
  end if;

  if has_function_privilege('public', v_sig, 'EXECUTE') then
    raise exception 'FAIL: PUBLIC has EXECUTE on save_cms_product_variant';
  end if;
  if has_function_privilege('anon', v_sig, 'EXECUTE') then
    raise exception 'FAIL: anon has EXECUTE on save_cms_product_variant';
  end if;
  if not has_function_privilege('authenticated', v_sig, 'EXECUTE') then
    raise exception
      'FAIL: authenticated missing EXECUTE on save_cms_product_variant';
  end if;
  if not has_function_privilege('service_role', v_sig, 'EXECUTE') then
    raise exception
      'FAIL: service_role missing EXECUTE on save_cms_product_variant';
  end if;

  v_call := format(
    $sql$
      select variant_id
      from public.save_cms_product_variant(
        %L::uuid, %L::uuid, 'CMS-COST-A-S1-LOW', 'A sort 1 low id',
        null, null, null, null, null, null, 'item', 110000, null,
        'unchanged', null, 'unchanged', null, '{}'::jsonb, false, true, 1
      )
    $sql$,
    'a2620000-0000-4000-8000-000000000001',
    'a2630000-0000-4000-8000-000000000002'
  );

  perform pg_temp.cms_set_anon();
  perform pg_temp.cms_assert_execute_denied(
    'anon save_cms_product_variant EXECUTE',
    v_call
  );
  perform pg_temp.cms_clear_auth();

  perform pg_temp.cms_set_auth('a2600000-0000-4000-8000-000000000001');
  perform pg_temp.cms_assert_authz_denied(
    'customer save_cms_product_variant',
    v_call
  );
  perform pg_temp.cms_clear_auth();

  perform pg_temp.cms_set_auth('a2600000-0000-4000-8000-000000000004');
  perform pg_temp.cms_assert_authz_denied(
    'inactive staff save_cms_product_variant',
    v_call
  );
  perform pg_temp.cms_clear_auth();

  perform pg_temp.cms_set_auth_forged_staff(
    'a2600000-0000-4000-8000-000000000007'
  );
  perform pg_temp.cms_assert_authz_denied(
    'forged metadata save_cms_product_variant',
    v_call
  );
  perform pg_temp.cms_clear_auth();

  foreach v_actor in array array[
    'a2600000-0000-4000-8000-000000000002'::uuid,
    'a2600000-0000-4000-8000-000000000003'::uuid
  ] loop
    perform pg_temp.cms_set_auth(v_actor);

    -- RETURNS TABLE with one column aliases as the scalar, not a composite.
    select jsonb_build_object('variant_id', q.variant_id)
    into v_returned
    from public.save_cms_product_variant(
      'a2620000-0000-4000-8000-000000000001'::uuid,
      'a2630000-0000-4000-8000-000000000002'::uuid,
      'CMS-COST-A-S1-LOW',
      'A sort 1 low id',
      null, null, null, null, null, null,
      'item',
      110000,
      null,
      'unchanged',
      null,
      'unchanged',
      null,
      '{}'::jsonb,
      false,
      true,
      1
    ) as q(variant_id);

    if v_returned is null then
      perform pg_temp.cms_clear_auth();
      raise exception 'FAIL: actor % save returned no row', v_actor;
    end if;
    if v_returned ? 'cost_price' or v_returned ? 'barcode' then
      perform pg_temp.cms_clear_auth();
      raise exception
        'FAIL: actor % save returned protected columns',
        v_actor;
    end if;
    if jsonb_typeof(v_returned) is distinct from 'object'
       or v_returned ->> 'variant_id' is null
       or exists (
         select 1
         from jsonb_each(v_returned) as e(k, v)
         where e.k not in ('variant_id')
       )
       or (
         select count(*) from jsonb_each(v_returned) as e(k, v)
       ) <> 1
    then
      perform pg_temp.cms_clear_auth();
      raise exception 'FAIL: actor % save return keys mismatch', v_actor;
    end if;

    v_id := (v_returned ->> 'variant_id')::uuid;
    if v_id is distinct from 'a2630000-0000-4000-8000-000000000002'::uuid then
      perform pg_temp.cms_clear_auth();
      raise exception 'FAIL: actor % save returned unexpected id', v_actor;
    end if;

    perform pg_temp.cms_clear_auth();
  end loop;

  raise notice 'OK: save_cms_product_variant definition + denial + return';
exception
  when others then
    perform pg_temp.cms_clear_auth();
    raise;
end $$;

-- ---------------------------------------------------------------------------
-- set_cms_product_image_primary / reorder_cms_product_images contracts
-- ---------------------------------------------------------------------------
do $$
declare
  v_primary_sig text := 'public.set_cms_product_image_primary(uuid, uuid)';
  v_reorder_sig text := 'public.reorder_cms_product_images(uuid, uuid[])';
  v_volatile "char";
  v_secdef boolean;
  v_config text[];
  v_out_names text[];
begin
  select p.provolatile, p.prosecdef, p.proconfig
  into v_volatile, v_secdef, v_config
  from pg_proc p
  where p.oid = v_primary_sig::regprocedure;

  if v_volatile is distinct from 'v' then
    raise exception 'FAIL: set_cms_product_image_primary is not VOLATILE';
  end if;
  if v_secdef is not false then
    raise exception
      'FAIL: set_cms_product_image_primary is not SECURITY INVOKER';
  end if;
  if v_config is null
     or not exists (
       select 1
       from unnest(v_config) as cfg(val)
       where cfg.val in ('search_path=', 'search_path=""')
     )
  then
    raise exception
      'FAIL: set_cms_product_image_primary search_path is not empty';
  end if;

  select p.provolatile, p.prosecdef, p.proconfig
  into v_volatile, v_secdef, v_config
  from pg_proc p
  where p.oid = v_reorder_sig::regprocedure;

  if v_volatile is distinct from 'v' then
    raise exception 'FAIL: reorder_cms_product_images is not VOLATILE';
  end if;
  if v_secdef is not false then
    raise exception 'FAIL: reorder_cms_product_images is not SECURITY INVOKER';
  end if;
  if v_config is null
     or not exists (
       select 1
       from unnest(v_config) as cfg(val)
       where cfg.val in ('search_path=', 'search_path=""')
     )
  then
    raise exception
      'FAIL: reorder_cms_product_images search_path is not empty';
  end if;

  select coalesce(
    array_agg(args.argname order by args.ord) filter (where args.mode = 't'),
    array[]::text[]
  )
  into v_out_names
  from pg_proc p
  cross join lateral unnest(
    p.proargnames,
    p.proargmodes
  ) with ordinality as args(argname, mode, ord)
  where p.oid = v_primary_sig::regprocedure;
  if v_out_names is distinct from array['image_id'] then
    raise exception
      'FAIL: set_cms_product_image_primary return columns mismatch';
  end if;

  select coalesce(
    array_agg(args.argname order by args.ord) filter (where args.mode = 't'),
    array[]::text[]
  )
  into v_out_names
  from pg_proc p
  cross join lateral unnest(
    p.proargnames,
    p.proargmodes
  ) with ordinality as args(argname, mode, ord)
  where p.oid = v_reorder_sig::regprocedure;
  if v_out_names is distinct from array['product_id'] then
    raise exception
      'FAIL: reorder_cms_product_images return columns mismatch';
  end if;

  if has_function_privilege('public', v_primary_sig, 'EXECUTE')
     or has_function_privilege('anon', v_primary_sig, 'EXECUTE')
  then
    raise exception 'FAIL: set_cms_product_image_primary EXECUTE too broad';
  end if;
  if not has_function_privilege('authenticated', v_primary_sig, 'EXECUTE')
     or not has_function_privilege('service_role', v_primary_sig, 'EXECUTE')
  then
    raise exception 'FAIL: set_cms_product_image_primary EXECUTE missing';
  end if;
  if has_function_privilege('public', v_reorder_sig, 'EXECUTE')
     or has_function_privilege('anon', v_reorder_sig, 'EXECUTE')
  then
    raise exception 'FAIL: reorder_cms_product_images EXECUTE too broad';
  end if;
  if not has_function_privilege('authenticated', v_reorder_sig, 'EXECUTE')
     or not has_function_privilege('service_role', v_reorder_sig, 'EXECUTE')
  then
    raise exception 'FAIL: reorder_cms_product_images EXECUTE missing';
  end if;

  perform pg_temp.cms_set_anon();
  perform pg_temp.cms_assert_execute_denied(
    'anon set_cms_product_image_primary EXECUTE',
    $q$select image_id from public.set_cms_product_image_primary(
      '30000000-0000-4000-8000-000000000001'::uuid,
      '50000000-0000-4000-8000-000000000001'::uuid
    )$q$
  );
  perform pg_temp.cms_clear_auth();

  perform pg_temp.cms_set_auth('a2600000-0000-4000-8000-000000000001');
  perform pg_temp.cms_assert_authz_denied(
    'customer set_cms_product_image_primary',
    $q$select image_id from public.set_cms_product_image_primary(
      '30000000-0000-4000-8000-000000000001'::uuid,
      '50000000-0000-4000-8000-000000000001'::uuid
    )$q$
  );
  perform pg_temp.cms_clear_auth();

  raise notice 'OK: product media RPC definition + denial + return';
exception
  when others then
    perform pg_temp.cms_clear_auth();
    raise;
end $$;

rollback;

\echo '== done =='
