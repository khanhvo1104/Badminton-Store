-- Executable regression: CMS privileged audit ledger (TASK-042).
--
-- Run against an already migrated + seeded disposable local database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/14_cms_privileged_audit_trail.sql

\set ON_ERROR_STOP on
\echo '== CMS privileged audit trail regression (TASK-042) =='

begin;

create or replace function pg_temp.aud_insert_user(
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

create or replace function pg_temp.aud_set_auth(p_user_id uuid)
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

create or replace function pg_temp.aud_clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

create or replace function pg_temp.aud_cleanup_events()
returns void
language plpgsql
as $$
begin
  perform set_config('app.cms_audit_test_cleanup', '1', true);
  delete from public.cms_privileged_audit_events;
  perform set_config('app.cms_audit_test_cleanup', '', true);
end;
$$;

do $$
declare
  v_admin uuid := 'a4200000-0000-4000-8000-000000000101';
  v_staff uuid := 'a4200000-0000-4000-8000-000000000102';
  v_customer uuid := 'a4200000-0000-4000-8000-000000000103';
  v_category uuid := '10000000-0000-4000-8000-000000000099';
begin
  perform pg_temp.aud_cleanup_events();

  delete from public.staff_management_events
  where actor_id in (v_admin, v_staff)
     or target_id in (v_admin, v_staff, v_customer);
  delete from public.profiles
  where id in (v_admin, v_staff, v_customer);
  delete from auth.users
  where id in (v_admin, v_staff, v_customer);
  delete from public.categories where id = v_category;

  perform pg_temp.aud_insert_user(v_admin, 'audit-admin@example.invalid');
  perform pg_temp.aud_insert_user(v_staff, 'audit-staff@example.invalid');
  perform pg_temp.aud_insert_user(v_customer, 'audit-customer@example.invalid');

  perform set_config('app.trusted_staff_management', '1', true);
  update public.profiles
  set role = 'admin', is_active = true, full_name = 'Audit Admin'
  where id = v_admin;
  update public.profiles
  set role = 'staff', is_active = true, full_name = 'Audit Staff'
  where id = v_staff;
  update public.profiles
  set role = 'customer', is_active = true, full_name = 'Audit Customer'
  where id = v_customer;
  perform set_config('app.trusted_staff_management', '', true);
end;
$$;

\echo 'PASS: fixtures inserted'

-- Grant / EXECUTE matrix
do $$
begin
  if has_table_privilege('anon', 'public.cms_privileged_audit_events', 'SELECT') then
    raise exception 'FAIL: anon may SELECT cms_privileged_audit_events';
  end if;
  if has_table_privilege('authenticated', 'public.cms_privileged_audit_events', 'INSERT') then
    raise exception 'FAIL: authenticated may INSERT cms_privileged_audit_events';
  end if;
  if has_table_privilege('authenticated', 'public.cms_privileged_audit_events', 'UPDATE') then
    raise exception 'FAIL: authenticated may UPDATE cms_privileged_audit_events';
  end if;
  if has_table_privilege('authenticated', 'public.cms_privileged_audit_events', 'DELETE') then
    raise exception 'FAIL: authenticated may DELETE cms_privileged_audit_events';
  end if;
  if not has_table_privilege('authenticated', 'public.cms_privileged_audit_events', 'SELECT') then
    raise exception 'FAIL: authenticated missing SELECT grant on cms_privileged_audit_events';
  end if;

  if has_table_privilege('service_role', 'public.cms_privileged_audit_events', 'INSERT') then
    raise exception 'FAIL: service_role may INSERT cms_privileged_audit_events';
  end if;
  if has_table_privilege('service_role', 'public.cms_privileged_audit_events', 'UPDATE') then
    raise exception 'FAIL: service_role may UPDATE cms_privileged_audit_events';
  end if;
  if has_table_privilege('service_role', 'public.cms_privileged_audit_events', 'DELETE') then
    raise exception 'FAIL: service_role may DELETE cms_privileged_audit_events';
  end if;

  if has_function_privilege(
    'public',
    'public.list_cms_privileged_audit_events(text,text,uuid,timestamptz,timestamptz,timestamptz,uuid,integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: PUBLIC has EXECUTE on list_cms_privileged_audit_events';
  end if;
  if not has_function_privilege(
    'authenticated',
    'public.list_cms_privileged_audit_events(text,text,uuid,timestamptz,timestamptz,timestamptz,uuid,integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: authenticated missing EXECUTE on list_cms_privileged_audit_events';
  end if;
  if has_function_privilege(
    'service_role',
    'public.list_cms_privileged_audit_events(text,text,uuid,timestamptz,timestamptz,timestamptz,uuid,integer)',
    'EXECUTE'
  ) then
    raise exception 'FAIL: service_role has EXECUTE on list_cms_privileged_audit_events';
  end if;
end;
$$;

\echo 'PASS: grant and EXECUTE matrix'

-- Immutability + direct insert denial
do $$
declare
  v_admin uuid := 'a4200000-0000-4000-8000-000000000101';
  v_event uuid;
  v_count integer;
begin
  perform pg_temp.aud_set_auth(v_admin);

  begin
    insert into public.cms_privileged_audit_events (
      actor_id, entity_type, entity_id, action
    ) values (
      v_admin,
      'category',
      '10000000-0000-4000-8000-000000000001',
      'create'
    );
    raise exception 'FAIL: direct INSERT into cms_privileged_audit_events succeeded';
  exception
    when others then
      if sqlstate <> '42501' then
        raise;
      end if;
  end;

  select count(*) into v_count from public.cms_privileged_audit_events;
  if v_count <> 0 then
    raise exception 'FAIL: direct INSERT left audit rows behind';
  end if;

  perform pg_temp.aud_clear_auth();
end;
$$;

\echo 'PASS: direct INSERT denied'

-- Category create writes canonical audit row
do $$
declare
  v_admin uuid := 'a4200000-0000-4000-8000-000000000101';
  v_category uuid := '10000000-0000-4000-8000-000000000099';
  v_count integer;
  v_metadata jsonb;
begin
  perform pg_temp.aud_set_auth(v_admin);

  insert into public.categories (
    id, name, slug, sort_order, is_active
  ) values (
    v_category, 'Audit Test Category', 'audit-test-category', 999, true
  );

  select count(*)
  into v_count
  from public.cms_privileged_audit_events
  where entity_type = 'category'
    and entity_id = v_category
    and action = 'create';

  if v_count <> 1 then
    raise exception 'FAIL: expected one category create audit row';
  end if;

  select metadata
  into v_metadata
  from public.cms_privileged_audit_events
  where entity_type = 'category'
    and entity_id = v_category
    and action = 'create'
  limit 1;

  if v_metadata ? 'description'
     or v_metadata ? 'image_path'
     or v_metadata ? 'cost_price' then
    raise exception 'FAIL: category audit metadata contains disallowed keys';
  end if;

  perform pg_temp.aud_clear_auth();
end;
$$;

\echo 'PASS: category create audited'

-- Staff cannot list audit events; admin can
do $$
declare
  v_admin uuid := 'a4200000-0000-4000-8000-000000000101';
  v_staff uuid := 'a4200000-0000-4000-8000-000000000102';
  v_rows integer;
begin
  perform pg_temp.aud_set_auth(v_staff);
  begin
    perform *
    from public.list_cms_privileged_audit_events();
    raise exception 'FAIL: staff may execute list_cms_privileged_audit_events';
  exception
    when others then
      if sqlstate <> '42501' then
        raise;
      end if;
  end;
  perform pg_temp.aud_clear_auth();

  perform pg_temp.aud_set_auth(v_admin);
  select count(*) into v_rows
  from public.list_cms_privileged_audit_events();
  if v_rows < 1 then
    raise exception 'FAIL: admin audit RPC returned no rows';
  end if;
  perform pg_temp.aud_clear_auth();
end;
$$;

\echo 'PASS: admin-only audit RPC'

-- Staff management mirror excludes target_email
do $$
declare
  v_admin uuid := 'a4200000-0000-4000-8000-000000000101';
  v_staff uuid := 'a4200000-0000-4000-8000-000000000102';
  v_metadata jsonb;
begin
  perform pg_temp.aud_set_auth(v_admin);
  perform public.update_cms_staff(v_staff, null, false);
  perform pg_temp.aud_clear_auth();

  select metadata
  into v_metadata
  from public.cms_privileged_audit_events
  where entity_type = 'staff'
    and action = 'deactivate'
  order by occurred_at desc, id desc
  limit 1;

  if v_metadata is null then
    raise exception 'FAIL: staff deactivate audit row missing';
  end if;
  if v_metadata ? 'target_email' or v_metadata ? 'email' then
    raise exception 'FAIL: staff audit metadata leaked email';
  end if;
end;
$$;

\echo 'PASS: staff audit metadata sanitized'

-- UPDATE immutability
do $$
declare
  v_event uuid;
begin
  select id into v_event
  from public.cms_privileged_audit_events
  order by occurred_at desc, id desc
  limit 1;

  begin
    update public.cms_privileged_audit_events
    set action = 'delete'
    where id = v_event;
    raise exception 'FAIL: audit UPDATE succeeded';
  exception
    when others then
      if sqlstate <> '55000' then
        raise;
      end if;
  end;
end;
$$;

\echo 'PASS: audit immutability'

create or replace function pg_temp.aud_assert_invalid(
  p_label text,
  p_sql text
)
returns void
language plpgsql
as $$
declare
  v_invalid boolean := false;
begin
  begin
    execute p_sql;
  exception
    when others then
      if sqlstate = '22023' and sqlerrm = 'invalid request' then
        v_invalid := true;
      else
        raise exception
          'FAIL: % raised unexpected SQLSTATE %: %',
          p_label,
          sqlstate,
          sqlerrm;
      end if;
  end;

  if not v_invalid then
    raise exception 'FAIL: % expected invalid request', p_label;
  end if;
end;
$$;

-- Exact metadata validator rejects partial payloads
do $$
begin
  if public.validate_cms_privileged_audit_metadata(
    'category',
    'create',
    '{"slug":"demo","name":"Demo"}'::jsonb
  ) then
    raise exception 'FAIL: partial category metadata accepted';
  end if;

  if public.validate_cms_privileged_audit_metadata(
    'order',
    'status_transition',
    jsonb_build_object(
      'from_status', 'pending',
      'to_status', 'confirmed',
      'has_note', false,
      'note', 'secret'
    )
  ) then
    raise exception 'FAIL: order metadata accepted note key';
  end if;
end;
$$;

\echo 'PASS: exact metadata validation'

-- service_role cannot call append helper directly
do $$
declare
  v_admin uuid := 'a4200000-0000-4000-8000-000000000101';
begin
  begin
    execute 'set local role service_role';
    perform public.append_cms_privileged_audit_event(
      v_admin,
      'category',
      '10000000-0000-4000-8000-000000000001',
      'create',
      jsonb_build_object(
        'slug', 'forged-audit',
        'name', 'Forged',
        'is_active', true
      )
    );
    raise exception 'FAIL: service_role append_cms_privileged_audit_event succeeded';
  exception
    when insufficient_privilege then
      null;
    when others then
      if sqlstate <> '42501' then
        raise;
      end if;
  end;
  execute 'reset role';
end;
$$;

\echo 'PASS: service_role append denied'

-- service_role cannot forge rows via GUC + direct INSERT (table privilege denial)
do $$
declare
  v_admin uuid := 'a4200000-0000-4000-8000-000000000101';
begin
  begin
    execute 'set local role service_role';
    perform set_config('app.cms_audit_internal', '1', true);
    insert into public.cms_privileged_audit_events (
      actor_id, entity_type, entity_id, action, metadata
    ) values (
      v_admin,
      'category',
      '10000000-0000-4000-8000-000000000001',
      'create',
      jsonb_build_object(
        'slug', 'forged-audit',
        'name', 'Forged',
        'is_active', true
      )
    );
    raise exception 'FAIL: service_role GUC direct INSERT succeeded';
  exception
    when insufficient_privilege then
      null;
    when others then
      if sqlstate <> '42501' then
        raise;
      end if;
  end;
  execute 'reset role';
end;
$$;

\echo 'PASS: service_role GUC direct INSERT denied'

-- Additional trusted sources: brand, product, variant, media, inventory, order
do $$
declare
  v_admin uuid := 'a4200000-0000-4000-8000-000000000101';
  v_staff uuid := 'a4200000-0000-4000-8000-000000000102';
  v_brand uuid := '20000000-0000-4000-8000-000000000099';
  v_product uuid := '30000000-0000-4000-8000-000000000099';
  v_variant uuid := '40000000-0000-4000-8000-000000000099';
  v_image uuid := '50000000-0000-4000-8000-000000000099';
  v_seed_variant uuid := '40000000-0000-4000-8000-000000000001';
  v_order uuid := 'a4200000-0000-4000-8000-000000000201';
  v_customer uuid := 'a4200000-0000-4000-8000-000000000103';
  v_before integer;
  v_after integer;
begin
  perform pg_temp.aud_cleanup_events();
  delete from public.product_images where id = v_image;
  delete from public.product_variants where id = v_variant;
  delete from public.products where id = v_product;
  delete from public.brands where id = v_brand;
  delete from public.order_status_history where order_id = v_order;
  delete from public.order_items where order_id = v_order;
  delete from public.orders where id = v_order;

  perform pg_temp.aud_set_auth(v_admin);

  insert into public.brands (id, name, slug, sort_order, is_active)
  values (v_brand, 'Audit Brand', 'audit-brand', 999, true);

  insert into public.products (
    id, category_id, brand_id, name, slug, status, published_at
  ) values (
    v_product,
    '10000000-0000-4000-8000-000000000001',
    v_brand,
    'Audit Product',
    'audit-product',
    'draft',
    null
  );

  insert into public.product_variants (
    id, product_id, sku, name, unit, price, is_default, is_active, sort_order
  ) values (
    v_variant, v_product, 'AUDIT-SKU-1', 'Audit Variant', 'item', 100.00, true, true, 1
  );

  insert into public.product_images (
    id, product_id, storage_path, sort_order, is_primary
  ) values (
    v_image, v_product, 'product-images/audit-test/main.webp', 0, true
  );

  perform pg_temp.aud_clear_auth();
  perform pg_temp.aud_set_auth(v_admin);
  perform public.adjust_cms_inventory(
    v_seed_variant,
    'add_stock',
    1,
    null,
    'count_correction',
    null
  );
  perform pg_temp.aud_clear_auth();

  insert into public.orders (
    id,
    order_number,
    user_id,
    status,
    payment_method,
    payment_status,
    currency_code,
    subtotal,
    discount_total,
    shipping_fee,
    grand_total,
    recipient_name,
    recipient_phone,
    shipping_address
  ) values (
    v_order,
    'BDM-AUDIT-000001',
    v_customer,
    'pending',
    'cod',
    'unpaid',
    'VND',
    100.00,
    0,
    0,
    100.00,
    'Audit Recipient',
    '0900000001',
    '{"line1":"1 Audit St"}'::jsonb
  );

  select count(*) into v_before
  from public.cms_privileged_audit_events
  where entity_type = 'order';

  insert into public.order_status_history (
    order_id, from_status, to_status, changed_by
  ) values (
    v_order, null, 'pending', v_customer
  );

  select count(*) into v_after
  from public.cms_privileged_audit_events
  where entity_type = 'order';

  if v_after is distinct from v_before then
    raise exception 'FAIL: customer checkout seed wrote order audit row';
  end if;

  perform pg_temp.aud_set_auth(v_admin);
  perform public.transition_cms_order_status(v_order, 'confirmed', null);
  perform pg_temp.aud_clear_auth();

  if not exists (
    select 1
    from public.cms_privileged_audit_events
    where entity_type = 'order'
      and action = 'status_transition'
      and entity_id = v_order
      and metadata->>'from_status' = 'pending'
      and metadata->>'to_status' = 'confirmed'
      and not (metadata ? 'note')
  ) then
    raise exception 'FAIL: staff order transition audit row missing';
  end if;

  if not exists (
    select 1 from public.cms_privileged_audit_events where entity_type = 'brand'
  ) or not exists (
    select 1 from public.cms_privileged_audit_events where entity_type = 'product'
  ) or not exists (
    select 1 from public.cms_privileged_audit_events where entity_type = 'variant'
  ) or not exists (
    select 1 from public.cms_privileged_audit_events where entity_type = 'product_media'
  ) or not exists (
    select 1 from public.cms_privileged_audit_events where entity_type = 'inventory'
  ) then
    raise exception 'FAIL: expected brand/product/variant/media/inventory audit rows';
  end if;

  if exists (
    select 1
    from public.cms_privileged_audit_events
    where metadata ? 'storage_path'
       or metadata ? 'cost_price'
       or metadata ? 'note'
       or metadata ? 'email'
  ) then
    raise exception 'FAIL: audit metadata leaked forbidden fields';
  end if;
end;
$$;

\echo 'PASS: multi-source audit coverage'

-- DELETE immutability and incomplete cursor denial
do $$
declare
  v_admin uuid := 'a4200000-0000-4000-8000-000000000101';
  v_event uuid;
begin
  select id into v_event
  from public.cms_privileged_audit_events
  order by occurred_at desc, id desc
  limit 1;

  begin
    delete from public.cms_privileged_audit_events where id = v_event;
    raise exception 'FAIL: audit DELETE succeeded';
  exception
    when others then
      if sqlstate <> '55000' then
        raise;
      end if;
  end;

  perform pg_temp.aud_set_auth(v_admin);
  perform pg_temp.aud_assert_invalid(
    'half cursor',
    $q$select event_id from public.list_cms_privileged_audit_events(
      'all', 'all', null, null, null, timezone('utc', now()), null, 10
    )$q$
  );
  perform pg_temp.aud_clear_auth();
end;
$$;

\echo 'PASS: delete immutability and half-cursor denial'

-- Pagination ordering and filters
do $$
declare
  v_admin uuid := 'a4200000-0000-4000-8000-000000000101';
  v_first timestamptz;
  v_first_id uuid;
  v_has_more boolean;
  v_second timestamptz;
  v_brand_count integer;
begin
  perform pg_temp.aud_set_auth(v_admin);

  select occurred_at, event_id, has_more
  into v_first, v_first_id, v_has_more
  from public.list_cms_privileged_audit_events(
    'all', 'all', null, null, null, null, null, 2
  )
  order by occurred_at desc, event_id desc
  limit 1;

  select count(*) into v_brand_count
  from public.list_cms_privileged_audit_events(
    'brand', 'all', null, null, null, null, null, 10
  );

  if v_brand_count < 1 then
    raise exception 'FAIL: brand entity filter returned no rows';
  end if;

  if v_has_more is distinct from true then
    raise exception 'FAIL: expected has_more on first audit page';
  end if;

  select occurred_at
  into v_second
  from public.list_cms_privileged_audit_events(
    'all', 'all', null, null, null, v_first, v_first_id, 2
  )
  order by occurred_at desc, event_id desc
  limit 1 offset 1;

  if v_second is null or v_second > v_first then
    raise exception 'FAIL: cursor pagination ordering broke';
  end if;

  perform pg_temp.aud_clear_auth();
end;
$$;

\echo 'PASS: pagination and filters'

do $$
begin
  perform pg_temp.aud_cleanup_events();
end;
$$;

rollback;

\echo 'PASS: CMS privileged audit trail regression complete'
\echo 'PostgREST service_role GUC boundary: run 14_cms_privileged_audit_trail_postgrest.sh'
