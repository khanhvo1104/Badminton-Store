-- Executable regression: CMS product media primary/reorder RPCs (TASK-038).
--
-- Run against an already migrated + seeded disposable local database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/10_cms_product_media.sql
--
-- Assert only scenario labels, IDs, counts, nullability, and SQLSTATEs —
-- never print cost values, barcodes, JWTs, credentials, or caught internals.

\set ON_ERROR_STOP on
\echo '== CMS product media RPC regression (TASK-038) =='

begin;

create or replace function pg_temp.media_insert_user(
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

create or replace function pg_temp.media_set_auth(p_user_id uuid)
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

create or replace function pg_temp.media_set_auth_forged_staff(p_user_id uuid)
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

create or replace function pg_temp.media_clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

create or replace function pg_temp.media_set_anon()
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

create or replace function pg_temp.media_assert_authz_denied(
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
        perform pg_temp.media_clear_auth();
        raise exception 'FAIL: % raised 42501 with unexpected message', p_label;
      end if;
    when others then
      if sqlstate = '42501' and sqlerrm = 'not authorized' then
        v_denied := true;
      else
        perform pg_temp.media_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: % expected authorization denial', p_label;
  end if;
end;
$$;

create or replace function pg_temp.media_assert_execute_denied(
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
        perform pg_temp.media_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: % expected EXECUTE denial', p_label;
  end if;
end;
$$;

create or replace function pg_temp.media_assert_invalid(
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
        perform pg_temp.media_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: % expected invalid request', p_label;
  end if;
end;
$$;

create or replace function pg_temp.media_assert_invalid_variant(
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
      if sqlstate = '22023' and sqlerrm = 'invalid variant' then
        v_denied := true;
      else
        perform pg_temp.media_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: % expected invalid variant', p_label;
  end if;
end;
$$;

create or replace function pg_temp.media_assert_image_limit(
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
      if sqlstate = '22023' and sqlerrm = 'image limit exceeded' then
        v_denied := true;
      else
        perform pg_temp.media_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: % expected image limit exceeded', p_label;
  end if;
end;
$$;

create or replace function pg_temp.media_assert_not_found(
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
      if sqlstate = 'P0002' and sqlerrm = 'not found' then
        v_denied := true;
      else
        perform pg_temp.media_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: % expected not found', p_label;
  end if;
end;
$$;

select pg_temp.media_insert_user(
  'a3800000-0000-4000-8000-000000000001',
  'media-customer@example.invalid'
);
select pg_temp.media_insert_user(
  'a3800000-0000-4000-8000-000000000002',
  'media-staff@example.invalid'
);
select pg_temp.media_insert_user(
  'a3800000-0000-4000-8000-000000000003',
  'media-admin@example.invalid'
);
select pg_temp.media_insert_user(
  'a3800000-0000-4000-8000-000000000004',
  'media-inactive@example.invalid'
);

update public.profiles
set role = 'customer', full_name = 'Media Customer', is_active = true
where id = 'a3800000-0000-4000-8000-000000000001';

update public.profiles
set role = 'staff', full_name = 'Media Staff', is_active = true
where id = 'a3800000-0000-4000-8000-000000000002';

update public.profiles
set role = 'admin', full_name = 'Media Admin', is_active = true
where id = 'a3800000-0000-4000-8000-000000000003';

update public.profiles
set role = 'staff', full_name = 'Media Inactive', is_active = false
where id = 'a3800000-0000-4000-8000-000000000004';

insert into public.categories (id, name, slug, sort_order, is_active)
values (
  'a3810000-0000-4000-8000-000000000001',
  'Media Category',
  'media-rpc-category',
  380,
  true
);

insert into public.products (
  id, category_id, brand_id, name, slug, status, is_featured, published_at
) values
  (
    'a3820000-0000-4000-8000-000000000001',
    'a3810000-0000-4000-8000-000000000001',
    null,
    'Media Product A',
    'media-rpc-product-a',
    'draft',
    false,
    null
  ),
  (
    'a3820000-0000-4000-8000-000000000002',
    'a3810000-0000-4000-8000-000000000001',
    null,
    'Media Product B',
    'media-rpc-product-b',
    'draft',
    false,
    null
  );

insert into public.product_variants (
  id, product_id, sku, name, price, is_default, is_active, sort_order
) values
  (
    'a3830000-0000-4000-8000-000000000001',
    'a3820000-0000-4000-8000-000000000001',
    'MEDIA-A-1',
    'A one',
    1000,
    true,
    true,
    0
  ),
  (
    'a3830000-0000-4000-8000-000000000002',
    'a3820000-0000-4000-8000-000000000002',
    'MEDIA-B-1',
    'B one',
    900,
    true,
    true,
    0
  );

insert into public.product_images (
  id, product_id, variant_id, storage_path, alt_text, sort_order, is_primary
) values
  (
    'a3840000-0000-4000-8000-000000000001',
    'a3820000-0000-4000-8000-000000000001',
    null,
    'product-images/a3820000-0000-4000-8000-000000000001/one.webp',
    'One',
    0,
    true
  ),
  (
    'a3840000-0000-4000-8000-000000000002',
    'a3820000-0000-4000-8000-000000000001',
    null,
    'product-images/a3820000-0000-4000-8000-000000000001/two.webp',
    'Two',
    1,
    false
  ),
  (
    'a3840000-0000-4000-8000-000000000003',
    'a3820000-0000-4000-8000-000000000001',
    'a3830000-0000-4000-8000-000000000001',
    'product-images/a3820000-0000-4000-8000-000000000001/var.webp',
    'Variant',
    0,
    true
  ),
  (
    'a3840000-0000-4000-8000-000000000004',
    'a3820000-0000-4000-8000-000000000002',
    null,
    'product-images/a3820000-0000-4000-8000-000000000002/main.webp',
    'B main',
    0,
    true
  );

-- Definition, grants, return contract
do $$
declare
  v_primary_sig text :=
    'public.set_cms_product_image_primary(uuid, uuid)';
  v_reorder_sig text :=
    'public.reorder_cms_product_images(uuid, uuid[])';
  v_volatile "char";
  v_secdef boolean;
  v_config text[];
  v_out_names text[];
  v_out_types text[];
  v_primary text :=
    $q$select image_id from public.set_cms_product_image_primary(
      'a3820000-0000-4000-8000-000000000001'::uuid,
      'a3840000-0000-4000-8000-000000000002'::uuid
    )$q$;
  v_reorder text :=
    $q$select product_id from public.reorder_cms_product_images(
      'a3820000-0000-4000-8000-000000000001'::uuid,
      array[
        'a3840000-0000-4000-8000-000000000001'::uuid,
        'a3840000-0000-4000-8000-000000000002'::uuid,
        'a3840000-0000-4000-8000-000000000003'::uuid
      ]
    )$q$;
  col text;
  bad_cols text[] := array[
    'cost_price', 'barcode', 'quantity_reserved', 'reorder_level',
    'quantity_on_hand', 'storage_path'
  ];
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

  select
    coalesce(
      array_agg(x.argname order by x.ord) filter (where x.mode = 't'),
      array[]::text[]
    ),
    coalesce(
      array_agg(x.typ order by x.ord) filter (where x.mode = 't'),
      array[]::text[]
    )
  into v_out_names, v_out_types
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
      where p.oid = v_primary_sig::regprocedure
    ) as t
  ) as x;

  if v_out_names is distinct from array['image_id']
     or v_out_types is distinct from array['uuid']
  then
    raise exception
      'FAIL: set_cms_product_image_primary return is not image_id uuid';
  end if;

  select
    coalesce(
      array_agg(x.argname order by x.ord) filter (where x.mode = 't'),
      array[]::text[]
    ),
    coalesce(
      array_agg(x.typ order by x.ord) filter (where x.mode = 't'),
      array[]::text[]
    )
  into v_out_names, v_out_types
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
      where p.oid = v_reorder_sig::regprocedure
    ) as t
  ) as x;

  if v_out_names is distinct from array['product_id']
     or v_out_types is distinct from array['uuid']
  then
    raise exception
      'FAIL: reorder_cms_product_images return is not product_id uuid';
  end if;

  foreach col in array bad_cols loop
    if exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      cross join lateral unnest(p.proargnames, p.proargmodes)
        as args(argname, mode)
      where n.nspname = 'public'
        and p.proname in (
          'set_cms_product_image_primary',
          'reorder_cms_product_images',
          'insert_cms_product_image',
          'update_cms_product_image'
        )
        and args.mode = 't'
        and args.argname = col
    ) then
      raise exception 'FAIL: media RPC returns protected column %', col;
    end if;
  end loop;

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

  perform pg_temp.media_set_anon();
  perform pg_temp.media_assert_execute_denied(
    'anon set_cms_product_image_primary',
    v_primary
  );
  perform pg_temp.media_clear_auth();

  perform pg_temp.media_set_auth('a3800000-0000-4000-8000-000000000001');
  perform pg_temp.media_assert_authz_denied(
    'customer set_cms_product_image_primary',
    v_primary
  );
  perform pg_temp.media_clear_auth();

  perform pg_temp.media_set_auth('a3800000-0000-4000-8000-000000000004');
  perform pg_temp.media_assert_authz_denied(
    'inactive set_cms_product_image_primary',
    v_primary
  );
  perform pg_temp.media_clear_auth();

  perform pg_temp.media_set_auth_forged_staff(
    'a3800000-0000-4000-8000-000000000001'
  );
  perform pg_temp.media_assert_authz_denied(
    'forged set_cms_product_image_primary',
    v_primary
  );
  perform pg_temp.media_assert_authz_denied(
    'forged reorder_cms_product_images',
    v_reorder
  );
  perform pg_temp.media_clear_auth();

  perform pg_temp.media_set_auth('a3800000-0000-4000-8000-000000000001');
  perform pg_temp.media_assert_authz_denied(
    'customer reorder_cms_product_images',
    v_reorder
  );
  perform pg_temp.media_clear_auth();

  raise notice 'OK: media RPC definition + grants + denial';
exception
  when others then
    perform pg_temp.media_clear_auth();
    raise;
end $$;

-- Staff/admin success, unique primary, cross-product, reorder bounds
do $$
declare
  v_id uuid;
  v_primary_count integer;
  v_order uuid[];
  v_actor uuid;
  v_returned jsonb;
begin
  foreach v_actor in array array[
    'a3800000-0000-4000-8000-000000000002'::uuid,
    'a3800000-0000-4000-8000-000000000003'::uuid
  ] loop
    perform pg_temp.media_set_auth(v_actor);

    select jsonb_build_object('image_id', q.image_id)
    into v_returned
    from public.set_cms_product_image_primary(
      'a3820000-0000-4000-8000-000000000001'::uuid,
      'a3840000-0000-4000-8000-000000000002'::uuid
    ) as q(image_id);

    if v_returned is null
       or jsonb_typeof(v_returned) is distinct from 'object'
       or v_returned ? 'cost_price'
       or v_returned ? 'barcode'
       or v_returned ? 'storage_path'
       or exists (
         select 1
         from jsonb_each(v_returned) as e(k, v)
         where e.k not in ('image_id')
       )
    then
      perform pg_temp.media_clear_auth();
      raise exception 'FAIL: actor % primary return contract', v_actor;
    end if;

    v_id := (v_returned ->> 'image_id')::uuid;
    if v_id is distinct from 'a3840000-0000-4000-8000-000000000002'::uuid then
      perform pg_temp.media_clear_auth();
      raise exception 'FAIL: actor % primary returned unexpected id', v_actor;
    end if;

    select count(*)::integer
    into v_primary_count
    from public.product_images
    where product_id = 'a3820000-0000-4000-8000-000000000001'
      and variant_id is null
      and is_primary = true;
    if v_primary_count <> 1 then
      perform pg_temp.media_clear_auth();
      raise exception 'FAIL: actor % left % general primaries', v_actor, v_primary_count;
    end if;

    perform pg_temp.media_clear_auth();
  end loop;

  perform pg_temp.media_set_auth('a3800000-0000-4000-8000-000000000002');

  perform pg_temp.media_assert_invalid(
    'cross-product primary',
    $q$select image_id from public.set_cms_product_image_primary(
      'a3820000-0000-4000-8000-000000000001'::uuid,
      'a3840000-0000-4000-8000-000000000004'::uuid
    )$q$
  );

  perform pg_temp.media_assert_not_found(
    'missing image primary',
    $q$select image_id from public.set_cms_product_image_primary(
      'a3820000-0000-4000-8000-000000000001'::uuid,
      'a3840000-0000-4000-8000-000000000099'::uuid
    )$q$
  );

  perform pg_temp.media_assert_not_found(
    'missing product primary',
    $q$select image_id from public.set_cms_product_image_primary(
      'a3820000-0000-4000-8000-000000000099'::uuid,
      'a3840000-0000-4000-8000-000000000001'::uuid
    )$q$
  );

  select jsonb_build_object('product_id', q.product_id)
  into v_returned
  from public.reorder_cms_product_images(
    'a3820000-0000-4000-8000-000000000001'::uuid,
    array[
      'a3840000-0000-4000-8000-000000000003'::uuid,
      'a3840000-0000-4000-8000-000000000002'::uuid,
      'a3840000-0000-4000-8000-000000000001'::uuid
    ]
  ) as q(product_id);

  if v_returned ->> 'product_id' is distinct from
       'a3820000-0000-4000-8000-000000000001'
     or v_returned ? 'cost_price'
     or exists (
       select 1 from jsonb_each(v_returned) as e(k, v)
       where e.k not in ('product_id')
     )
  then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: reorder return contract';
  end if;

  select array_agg(id order by sort_order, id)
  into v_order
  from public.product_images
  where product_id = 'a3820000-0000-4000-8000-000000000001';

  if v_order is distinct from array[
    'a3840000-0000-4000-8000-000000000003'::uuid,
    'a3840000-0000-4000-8000-000000000002'::uuid,
    'a3840000-0000-4000-8000-000000000001'::uuid
  ] then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: reorder did not persist array order';
  end if;

  perform pg_temp.media_assert_invalid(
    'reorder missing id',
    $q$select product_id from public.reorder_cms_product_images(
      'a3820000-0000-4000-8000-000000000001'::uuid,
      array[
        'a3840000-0000-4000-8000-000000000001'::uuid,
        'a3840000-0000-4000-8000-000000000002'::uuid
      ]
    )$q$
  );

  perform pg_temp.media_assert_invalid(
    'reorder duplicate id',
    $q$select product_id from public.reorder_cms_product_images(
      'a3820000-0000-4000-8000-000000000001'::uuid,
      array[
        'a3840000-0000-4000-8000-000000000001'::uuid,
        'a3840000-0000-4000-8000-000000000002'::uuid,
        'a3840000-0000-4000-8000-000000000001'::uuid
      ]
    )$q$
  );

  perform pg_temp.media_assert_invalid(
    'reorder forged foreign id',
    $q$select product_id from public.reorder_cms_product_images(
      'a3820000-0000-4000-8000-000000000001'::uuid,
      array[
        'a3840000-0000-4000-8000-000000000001'::uuid,
        'a3840000-0000-4000-8000-000000000002'::uuid,
        'a3840000-0000-4000-8000-000000000004'::uuid
      ]
    )$q$
  );

  perform pg_temp.media_assert_invalid(
    'reorder empty',
    $q$select product_id from public.reorder_cms_product_images(
      'a3820000-0000-4000-8000-000000000001'::uuid,
      array[]::uuid[]
    )$q$
  );

  -- Variant-scope primary stays independent of general primary.
  perform public.set_cms_product_image_primary(
    'a3820000-0000-4000-8000-000000000001'::uuid,
    'a3840000-0000-4000-8000-000000000001'::uuid
  );

  select count(*)::integer
  into v_primary_count
  from public.product_images
  where id = 'a3840000-0000-4000-8000-000000000003'
    and is_primary = true;
  if v_primary_count <> 1 then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: variant primary was cleared by general switch';
  end if;

  perform pg_temp.media_clear_auth();
  raise notice 'OK: media RPC staff/admin behavior';
exception
  when others then
    perform pg_temp.media_clear_auth();
    raise;
end $$;

-- Atomic insert + primary, and variant reassignment + rollback
do $$
declare
  v_insert_sig text :=
    'public.insert_cms_product_image(uuid, text, text, uuid, boolean)';
  v_update_sig text :=
    'public.update_cms_product_image(uuid, uuid, text, uuid, integer)';
  v_count integer;
  v_primary_count integer;
  v_id uuid;
  v_variant uuid;
  v_is_primary boolean;
  v_returned jsonb;
begin
  if has_function_privilege('public', v_insert_sig, 'EXECUTE')
     or has_function_privilege('anon', v_insert_sig, 'EXECUTE')
     or has_function_privilege('public', v_update_sig, 'EXECUTE')
     or has_function_privilege('anon', v_update_sig, 'EXECUTE')
  then
    raise exception 'FAIL: insert/update media RPC EXECUTE too broad';
  end if;
  if not has_function_privilege('authenticated', v_insert_sig, 'EXECUTE')
     or not has_function_privilege('authenticated', v_update_sig, 'EXECUTE')
  then
    raise exception 'FAIL: insert/update media RPC EXECUTE missing';
  end if;

  perform pg_temp.media_set_auth('a3800000-0000-4000-8000-000000000001');
  perform pg_temp.media_assert_authz_denied(
    'customer insert_cms_product_image',
    $q$select image_id from public.insert_cms_product_image(
      'a3820000-0000-4000-8000-000000000001'::uuid,
      'product-images/a3820000-0000-4000-8000-000000000001/a3890000-0000-4000-8000-000000000010.webp',
      'Nope',
      null,
      true
    )$q$
  );
  perform pg_temp.media_assert_authz_denied(
    'customer update_cms_product_image',
    $q$select image_id from public.update_cms_product_image(
      'a3820000-0000-4000-8000-000000000001'::uuid,
      'a3840000-0000-4000-8000-000000000001'::uuid,
      'Nope',
      'a3830000-0000-4000-8000-000000000001'::uuid,
      0
    )$q$
  );
  perform pg_temp.media_clear_auth();

  perform pg_temp.media_set_auth('a3800000-0000-4000-8000-000000000002');

  select count(*)::integer
  into v_count
  from public.product_images
  where product_id = 'a3820000-0000-4000-8000-000000000001';

  perform pg_temp.media_assert_invalid(
    'insert forged storage_path',
    $q$select image_id from public.insert_cms_product_image(
      'a3820000-0000-4000-8000-000000000001'::uuid,
      'product-images/a3820000-0000-4000-8000-000000000002/evil.webp',
      'Nope',
      null,
      true
    )$q$
  );

  if (
    select count(*)::integer
    from public.product_images
    where product_id = 'a3820000-0000-4000-8000-000000000001'
  ) is distinct from v_count then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: invalid insert left a product image row';
  end if;

  perform pg_temp.media_assert_invalid_variant(
    'insert foreign variant',
    $q$select image_id from public.insert_cms_product_image(
      'a3820000-0000-4000-8000-000000000001'::uuid,
      'product-images/a3820000-0000-4000-8000-000000000001/a3890000-0000-4000-8000-000000000011.webp',
      'Nope',
      'a3830000-0000-4000-8000-000000000002'::uuid,
      false
    )$q$
  );

  if (
    select count(*)::integer
    from public.product_images
    where product_id = 'a3820000-0000-4000-8000-000000000001'
  ) is distinct from v_count then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: invalid-variant insert left a product image row';
  end if;

  perform pg_temp.media_assert_invalid_variant(
    'update foreign variant',
    $q$select image_id from public.update_cms_product_image(
      'a3820000-0000-4000-8000-000000000001'::uuid,
      'a3840000-0000-4000-8000-000000000001'::uuid,
      'Still general',
      'a3830000-0000-4000-8000-000000000002'::uuid,
      4
    )$q$
  );

  select variant_id, is_primary
  into v_variant, v_is_primary
  from public.product_images
  where id = 'a3840000-0000-4000-8000-000000000001';
  if v_variant is not null or v_is_primary is not true then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: invalid update changed primary general image';
  end if;

  select jsonb_build_object('image_id', q.image_id)
  into v_returned
  from public.update_cms_product_image(
    'a3820000-0000-4000-8000-000000000001'::uuid,
    'a3840000-0000-4000-8000-000000000001'::uuid,
    'Moved',
    'a3830000-0000-4000-8000-000000000001'::uuid,
    2
  ) as q(image_id);

  if v_returned ->> 'image_id' is distinct from
       'a3840000-0000-4000-8000-000000000001'
     or v_returned ? 'cost_price'
     or exists (
       select 1 from jsonb_each(v_returned) as e(k, v)
       where e.k not in ('image_id')
     )
  then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: update return contract';
  end if;

  select variant_id, is_primary
  into v_variant, v_is_primary
  from public.product_images
  where id = 'a3840000-0000-4000-8000-000000000001';
  if v_variant is distinct from 'a3830000-0000-4000-8000-000000000001'::uuid
     or v_is_primary is not false
  then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: moved primary did not join destination as gallery';
  end if;

  select count(*)::integer
  into v_primary_count
  from public.product_images
  where product_id = 'a3820000-0000-4000-8000-000000000001'
    and variant_id is null
    and is_primary = true;
  if v_primary_count <> 1 then
    perform pg_temp.media_clear_auth();
    raise exception
      'FAIL: move left % general primaries',
      v_primary_count;
  end if;

  select id
  into v_id
  from public.product_images
  where product_id = 'a3820000-0000-4000-8000-000000000001'
    and variant_id is null
    and is_primary = true;
  if v_id is distinct from 'a3840000-0000-4000-8000-000000000002'::uuid then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: old scope did not promote remaining general image';
  end if;

  select count(*)::integer
  into v_primary_count
  from public.product_images
  where variant_id = 'a3830000-0000-4000-8000-000000000001'
    and is_primary = true;
  if v_primary_count <> 1 then
    perform pg_temp.media_clear_auth();
    raise exception
      'FAIL: move left % variant primaries',
      v_primary_count;
  end if;

  select jsonb_build_object('image_id', q.image_id)
  into v_returned
  from public.insert_cms_product_image(
    'a3820000-0000-4000-8000-000000000001'::uuid,
    'product-images/a3820000-0000-4000-8000-000000000001/a3890000-0000-4000-8000-000000000010.webp',
    'New primary',
    null,
    true
  ) as q(image_id);

  v_id := (v_returned ->> 'image_id')::uuid;
  if v_id is null
     or v_returned ? 'cost_price'
     or exists (
       select 1 from jsonb_each(v_returned) as e(k, v)
       where e.k not in ('image_id')
     )
  then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: insert return contract';
  end if;

  select count(*)::integer
  into v_primary_count
  from public.product_images
  where product_id = 'a3820000-0000-4000-8000-000000000001'
    and variant_id is null
    and is_primary = true;
  if v_primary_count <> 1 then
    perform pg_temp.media_clear_auth();
    raise exception
      'FAIL: insert left % general primaries',
      v_primary_count;
  end if;

  select is_primary
  into v_is_primary
  from public.product_images
  where id = v_id;
  if v_is_primary is not true then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: insert set_primary did not assign the new row';
  end if;

  select is_primary
  into v_is_primary
  from public.product_images
  where id = 'a3840000-0000-4000-8000-000000000002';
  if v_is_primary is not false then
    perform pg_temp.media_clear_auth();
    raise exception 'FAIL: insert set_primary did not unset previous primary';
  end if;

  perform pg_temp.media_clear_auth();
  raise notice 'OK: media insert/update atomic behavior';
exception
  when others then
    perform pg_temp.media_clear_auth();
    raise;
end $$;


rollback;

\echo '== done =='
