-- Executable regression: CMS variant editor save RPC (TASK-036).
--
-- Run against an already migrated + seeded disposable local database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/08_cms_variant_editor.sql
--
-- Assert only scenario labels, IDs, counts, nullability, and SQLSTATEs —
-- never print cost values, barcodes, JWTs, credentials, or caught internals.

\set ON_ERROR_STOP on
\echo '== CMS variant editor RPC regression (TASK-036) =='

begin;

create or replace function pg_temp.editor_insert_user(
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

create or replace function pg_temp.editor_set_auth(p_user_id uuid)
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

create or replace function pg_temp.editor_clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

create or replace function pg_temp.editor_save(
  p_product_id uuid,
  p_variant_id uuid default null,
  p_sku text default 'SKU-EDITOR-1',
  p_name text default null,
  p_color_name text default null,
  p_color_hex text default null,
  p_racket_weight_class text default null,
  p_grip_size text default null,
  p_shoe_size text default null,
  p_clothing_size text default null,
  p_unit text default 'item',
  p_price numeric default 1000,
  p_compare_at_price numeric default null,
  p_cost_mode text default 'unchanged',
  p_cost_price numeric default null,
  p_barcode_mode text default 'unchanged',
  p_barcode text default null,
  p_attributes jsonb default '{}'::jsonb,
  p_is_default boolean default false,
  p_is_active boolean default true,
  p_sort_order integer default 0
)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
begin
  select q.variant_id
  into v_id
  from public.save_cms_product_variant(
    p_product_id,
    p_variant_id,
    p_sku,
    p_name,
    p_color_name,
    p_color_hex,
    p_racket_weight_class,
    p_grip_size,
    p_shoe_size,
    p_clothing_size,
    p_unit,
    p_price,
    p_compare_at_price,
    p_cost_mode,
    p_cost_price,
    p_barcode_mode,
    p_barcode,
    p_attributes,
    p_is_default,
    p_is_active,
    p_sort_order
  ) as q(variant_id);
  return v_id;
end;
$$;

select pg_temp.editor_insert_user(
  'a3600000-0000-4000-8000-000000000001',
  'variant-editor-customer@example.invalid'
);
select pg_temp.editor_insert_user(
  'a3600000-0000-4000-8000-000000000002',
  'variant-editor-staff@example.invalid'
);
select pg_temp.editor_insert_user(
  'a3600000-0000-4000-8000-000000000003',
  'variant-editor-admin@example.invalid'
);

update public.profiles
set role = 'staff', full_name = 'Variant Editor Staff', is_active = true
where id = 'a3600000-0000-4000-8000-000000000002';

update public.profiles
set role = 'admin', full_name = 'Variant Editor Admin', is_active = true
where id = 'a3600000-0000-4000-8000-000000000003';

insert into public.categories (id, name, slug, sort_order, is_active)
values (
  'a3610000-0000-4000-8000-000000000001',
  'Variant Editor Category',
  'variant-editor-category',
  360,
  true
);

insert into public.products (
  id, category_id, brand_id, name, slug, status, is_featured, published_at
) values
  (
    'a3620000-0000-4000-8000-000000000001',
    'a3610000-0000-4000-8000-000000000001',
    null,
    'Variant Editor Product A',
    'variant-editor-product-a',
    'draft',
    false,
    null
  ),
  (
    'a3620000-0000-4000-8000-000000000002',
    'a3610000-0000-4000-8000-000000000001',
    null,
    'Variant Editor Product B',
    'variant-editor-product-b',
    'draft',
    false,
    null
  ),
  (
    'a3620000-0000-4000-8000-000000000003',
    'a3610000-0000-4000-8000-000000000001',
    null,
    'Variant Editor Product Empty',
    'variant-editor-product-empty',
    'draft',
    false,
    null
  );

insert into public.product_variants (
  id, product_id, sku, name, price, is_default, is_active, sort_order
) values
  (
    'a3630000-0000-4000-8000-000000000001',
    'a3620000-0000-4000-8000-000000000001',
    'VE-A-DEFAULT',
    'A default',
    1000,
    true,
    true,
    0
  ),
  (
    'a3630000-0000-4000-8000-000000000002',
    'a3620000-0000-4000-8000-000000000001',
    'VE-A-OTHER',
    'A other',
    1100,
    false,
    true,
    1
  ),
  (
    'a3630000-0000-4000-8000-000000000010',
    'a3620000-0000-4000-8000-000000000002',
    'VE-B-ONLY',
    'B only',
    900,
    true,
    true,
    0
  );

-- Staff/admin success, first-variant default, atomic default switch, reject
-- unsetting the current default, cross-product denial, uniqueness, compare,
-- JSON attacks, cost/barcode contracts, and statement rollback.
do $$
declare
  v_staff uuid := 'a3600000-0000-4000-8000-000000000002';
  v_admin uuid := 'a3600000-0000-4000-8000-000000000003';
  v_product_a uuid := 'a3620000-0000-4000-8000-000000000001';
  v_product_b uuid := 'a3620000-0000-4000-8000-000000000002';
  v_product_empty uuid := 'a3620000-0000-4000-8000-000000000003';
  v_default uuid := 'a3630000-0000-4000-8000-000000000001';
  v_other uuid := 'a3630000-0000-4000-8000-000000000002';
  v_b uuid := 'a3630000-0000-4000-8000-000000000010';
  v_created uuid;
  v_second uuid;
  v_denied boolean;
  v_default_count integer;
  v_is_null boolean;
  v_is_zero boolean;
  v_has_positive boolean;
  v_barcode_null boolean;
  v_sku text;
  v_actor uuid;
begin
  foreach v_actor in array array[v_staff, v_admin] loop
    perform pg_temp.editor_set_auth(v_actor);

    v_created := pg_temp.editor_save(
      p_product_id => v_product_empty,
      p_sku => 'VE-EMPTY-FIRST-' || substr(v_actor::text, 1, 8),
      p_is_default => false
    );

    select count(*) filter (where is_default)
    into v_default_count
    from public.product_variants
    where product_id = v_product_empty;

    if v_default_count <> 1 then
      perform pg_temp.editor_clear_auth();
      raise exception 'FAIL: first variant was not forced default';
    end if;

    select is_default
    into v_denied
    from public.product_variants
    where id = v_created;
    if v_denied is not true then
      perform pg_temp.editor_clear_auth();
      raise exception 'FAIL: created first variant is not default';
    end if;

    delete from public.product_variants where product_id = v_product_empty;
    perform pg_temp.editor_clear_auth();
  end loop;

  perform pg_temp.editor_set_auth(v_staff);

  v_created := pg_temp.editor_save(
    p_product_id => v_product_empty,
    p_sku => 'VE-EMPTY-1',
    p_is_default => false,
    p_cost_mode => 'set',
    p_cost_price => 0,
    p_barcode_mode => 'set',
    p_barcode => 'BAR-EMPTY-1'
  );

  select
    (q.cost_price is null),
    (q.cost_price = 0),
    (q.cost_price is not null and q.cost_price <> 0)
  into v_is_null, v_is_zero, v_has_positive
  from public.get_staff_variant_costs(v_product_empty) as q
  where q.variant_id = v_created;

  if v_is_null or not v_is_zero or v_has_positive then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: zero cost was not distinguishable from null';
  end if;

  v_second := pg_temp.editor_save(
    p_product_id => v_product_empty,
    p_sku => 'VE-EMPTY-2',
    p_is_default => true,
    p_cost_mode => 'clear',
    p_barcode_mode => 'unchanged'
  );

  select count(*) filter (where is_default)
  into v_default_count
  from public.product_variants
  where product_id = v_product_empty;
  if v_default_count <> 1 then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: default switch left multiple defaults';
  end if;

  select is_default into v_denied
  from public.product_variants where id = v_created;
  if v_denied is not false then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: prior default was not unset';
  end if;

  select is_default into v_denied
  from public.product_variants where id = v_second;
  if v_denied is not true then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: target was not set as default';
  end if;

  v_denied := false;
  begin
    perform pg_temp.editor_save(
      p_product_id => v_product_empty,
      p_variant_id => v_second,
      p_sku => 'VE-EMPTY-2',
      p_is_default => false
    );
  exception
    when others then
      if sqlstate = '22023' and sqlerrm = 'invalid request' then
        v_denied := true;
      else
        perform pg_temp.editor_clear_auth();
        raise exception
          'FAIL: unset default raised unexpected SQLSTATE %',
          sqlstate;
      end if;
  end;
  if not v_denied then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: unsetting the current default was allowed';
  end if;

  select is_default into v_denied
  from public.product_variants where id = v_second;
  if v_denied is not true then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: rejected unset default still changed state';
  end if;

  perform pg_temp.editor_save(
    p_product_id => v_product_a,
    p_variant_id => v_other,
    p_sku => 'VE-A-OTHER',
    p_is_default => true
  );

  select count(*) filter (where is_default)
  into v_default_count
  from public.product_variants
  where product_id = v_product_a;
  if v_default_count <> 1 then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: product A has % defaults', v_default_count;
  end if;
  select is_default into v_denied
  from public.product_variants where id = v_other;
  if v_denied is not true then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: product A default did not move to target';
  end if;

  v_denied := false;
  begin
    perform pg_temp.editor_save(
      p_product_id => v_product_b,
      p_variant_id => v_other,
      p_sku => 'VE-CROSS',
      p_is_default => false
    );
  exception
    when others then
      if sqlstate = '22023' and sqlerrm = 'invalid request' then
        v_denied := true;
      else
        perform pg_temp.editor_clear_auth();
        raise exception
          'FAIL: cross-product update raised unexpected SQLSTATE %',
          sqlstate;
      end if;
  end;
  if not v_denied then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: cross-product update was allowed';
  end if;

  select sku into v_sku
  from public.product_variants where id = v_other;
  if v_sku is distinct from 'VE-A-OTHER' then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: cross-product attempt mutated the variant';
  end if;

  v_denied := false;
  begin
    perform pg_temp.editor_save(
      p_product_id => v_product_a,
      p_sku => 'VE-B-ONLY',
      p_is_default => false
    );
  exception
    when unique_violation then
      v_denied := true;
    when others then
      perform pg_temp.editor_clear_auth();
      raise exception 'FAIL: duplicate SKU raised unexpected SQLSTATE %', sqlstate;
  end;
  if not v_denied then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: duplicate SKU was allowed';
  end if;

  perform pg_temp.editor_save(
    p_product_id => v_product_a,
    p_variant_id => v_default,
    p_sku => 'VE-A-DEFAULT',
    p_barcode_mode => 'set',
    p_barcode => 'BAR-SHARED'
  );

  v_denied := false;
  begin
    perform pg_temp.editor_save(
      p_product_id => v_product_a,
      p_variant_id => v_other,
      p_sku => 'VE-A-OTHER',
      p_is_default => true,
      p_barcode_mode => 'set',
      p_barcode => 'BAR-SHARED'
    );
  exception
    when unique_violation then
      v_denied := true;
    when others then
      perform pg_temp.editor_clear_auth();
      raise exception
        'FAIL: duplicate barcode raised unexpected SQLSTATE %',
        sqlstate;
  end;
  if not v_denied then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: duplicate barcode was allowed';
  end if;

  v_denied := false;
  begin
    perform pg_temp.editor_save(
      p_product_id => v_product_a,
      p_variant_id => v_other,
      p_sku => 'VE-A-OTHER',
      p_price => 2000,
      p_compare_at_price => 1500,
      p_is_default => true
    );
  exception
    when others then
      if sqlstate = '22023' and sqlerrm = 'invalid request' then
        v_denied := true;
      else
        perform pg_temp.editor_clear_auth();
        raise exception
          'FAIL: compare < price raised unexpected SQLSTATE %',
          sqlstate;
      end if;
  end;
  if not v_denied then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: compare_at < price was allowed';
  end if;

  v_denied := false;
  begin
    perform pg_temp.editor_save(
      p_product_id => v_product_a,
      p_variant_id => v_other,
      p_sku => 'VE-A-OTHER',
      p_is_default => true,
      p_attributes => '[]'::jsonb
    );
  exception
    when others then
      if sqlstate = '22023' then
        v_denied := true;
      else
        perform pg_temp.editor_clear_auth();
        raise exception 'FAIL: array attributes SQLSTATE %', sqlstate;
      end if;
  end;
  if not v_denied then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: array attributes were allowed';
  end if;

  v_denied := false;
  begin
    perform pg_temp.editor_save(
      p_product_id => v_product_a,
      p_variant_id => v_other,
      p_sku => 'VE-A-OTHER',
      p_is_default => true,
      p_attributes => '{"__proto__": {"x": 1}}'::jsonb
    );
  exception
    when others then
      if sqlstate = '22023' then
        v_denied := true;
      else
        perform pg_temp.editor_clear_auth();
        raise exception 'FAIL: prototype key SQLSTATE %', sqlstate;
      end if;
  end;
  if not v_denied then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: prototype attribute key was allowed';
  end if;

  perform pg_temp.editor_save(
    p_product_id => v_product_empty,
    p_variant_id => v_created,
    p_sku => 'VE-EMPTY-1',
    p_cost_mode => 'set',
    p_cost_price => 12.50
  );
  select
    (q.cost_price is null),
    (q.cost_price = 0),
    (q.cost_price is not null and q.cost_price <> 0)
  into v_is_null, v_is_zero, v_has_positive
  from public.get_staff_variant_costs(v_product_empty) as q
  where q.variant_id = v_created;
  if v_is_null or v_is_zero or not v_has_positive then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: set cost did not store a positive cost';
  end if;

  perform pg_temp.editor_save(
    p_product_id => v_product_empty,
    p_variant_id => v_created,
    p_sku => 'VE-EMPTY-1',
    p_cost_mode => 'unchanged'
  );
  select
    (q.cost_price is null),
    (q.cost_price = 0),
    (q.cost_price is not null and q.cost_price <> 0)
  into v_is_null, v_is_zero, v_has_positive
  from public.get_staff_variant_costs(v_product_empty) as q
  where q.variant_id = v_created;
  if v_is_null or v_is_zero or not v_has_positive then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: unchanged cost did not preserve the positive cost';
  end if;

  perform pg_temp.editor_save(
    p_product_id => v_product_empty,
    p_variant_id => v_created,
    p_sku => 'VE-EMPTY-1',
    p_cost_mode => 'clear'
  );
  select
    (q.cost_price is null),
    (q.cost_price = 0)
  into v_is_null, v_is_zero
  from public.get_staff_variant_costs(v_product_empty) as q
  where q.variant_id = v_created;
  if not v_is_null or v_is_zero then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: cleared cost was not null';
  end if;

  perform pg_temp.editor_clear_auth();

  select (barcode is null)
  into v_barcode_null
  from public.product_variants
  where id = v_created;
  if v_barcode_null then
    raise exception 'FAIL: barcode unchanged/clear contract dropped the barcode';
  end if;

  perform pg_temp.editor_set_auth(v_staff);
  perform pg_temp.editor_save(
    p_product_id => v_product_empty,
    p_variant_id => v_created,
    p_sku => 'VE-EMPTY-1',
    p_barcode_mode => 'clear'
  );
  perform pg_temp.editor_clear_auth();

  select (barcode is null)
  into v_barcode_null
  from public.product_variants
  where id = v_created;
  if not v_barcode_null then
    raise exception 'FAIL: barcode clear left a barcode';
  end if;

  -- Statement-level rollback: a rejected compare must not keep a default switch.
  perform pg_temp.editor_set_auth(v_staff);
  v_denied := false;
  begin
    perform pg_temp.editor_save(
      p_product_id => v_product_a,
      p_variant_id => v_default,
      p_sku => 'VE-A-DEFAULT-MUTATED',
      p_price => 5000,
      p_compare_at_price => 1000,
      p_is_default => true
    );
  exception
    when others then
      if sqlstate = '22023' then
        v_denied := true;
      else
        perform pg_temp.editor_clear_auth();
        raise;
      end if;
  end;
  if not v_denied then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: invalid compare did not raise';
  end if;

  select sku, is_default
  into v_sku, v_denied
  from public.product_variants
  where id = v_default;
  if v_sku is distinct from 'VE-A-DEFAULT' then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: rejected save mutated SKU';
  end if;
  if v_denied is not false then
    perform pg_temp.editor_clear_auth();
    raise exception 'FAIL: rejected save restored an accidental default';
  end if;

  perform pg_temp.editor_clear_auth();
  raise notice 'OK: save_cms_product_variant staff/admin behavior';
exception
  when others then
    perform pg_temp.editor_clear_auth();
    raise;
end $$;

rollback;

\echo '== done =='
