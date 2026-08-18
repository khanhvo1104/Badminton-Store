-- Executable regression: CMS inventory explorer and adjustment RPCs (TASK-037).
--
-- Run against an already migrated + seeded disposable local database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/09_cms_inventory_adjustments.sql
--
-- Assert only scenario labels, IDs, counts, nullability, and SQLSTATEs —
-- never print cost values, barcodes, JWTs, credentials, or caught internals.

\set ON_ERROR_STOP on
\echo '== CMS inventory adjustments regression (TASK-037) =='

begin;

create or replace function pg_temp.inv_insert_user(
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

create or replace function pg_temp.inv_set_auth(p_user_id uuid)
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

create or replace function pg_temp.inv_clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

create or replace function pg_temp.inv_assert_authz_denied(
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
        perform pg_temp.inv_clear_auth();
        raise exception 'FAIL: % raised 42501 with unexpected message', p_label;
      end if;
    when others then
      if sqlstate = '42501' and sqlerrm = 'not authorized' then
        v_denied := true;
      else
        perform pg_temp.inv_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: % expected authorization denial', p_label;
  end if;
end;
$$;

create or replace function pg_temp.inv_assert_execute_denied(
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
        perform pg_temp.inv_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: % expected EXECUTE denial', p_label;
  end if;
end;
$$;

create or replace function pg_temp.inv_assert_invalid(
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
        perform pg_temp.inv_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: % expected invalid request', p_label;
  end if;
end;
$$;

create or replace function pg_temp.inv_assert_not_found(
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
        perform pg_temp.inv_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: % expected not found', p_label;
  end if;
end;
$$;

select pg_temp.inv_insert_user(
  'a3700000-0000-4000-8000-000000000001',
  'inventory-customer@example.invalid'
);
select pg_temp.inv_insert_user(
  'a3700000-0000-4000-8000-000000000002',
  'inventory-staff@example.invalid'
);
select pg_temp.inv_insert_user(
  'a3700000-0000-4000-8000-000000000003',
  'inventory-admin@example.invalid'
);
select pg_temp.inv_insert_user(
  'a3700000-0000-4000-8000-000000000004',
  'inventory-inactive@example.invalid'
);
select pg_temp.inv_insert_user(
  'a3700000-0000-4000-8000-000000000005',
  'inventory-noprofile@example.invalid'
);

update public.profiles
set role = 'staff', full_name = 'Inventory Staff', is_active = true
where id = 'a3700000-0000-4000-8000-000000000002';

update public.profiles
set role = 'admin', full_name = 'Inventory Admin', is_active = true
where id = 'a3700000-0000-4000-8000-000000000003';

update public.profiles
set role = 'staff', full_name = 'Inventory Inactive', is_active = false
where id = 'a3700000-0000-4000-8000-000000000004';

delete from public.profiles
where id = 'a3700000-0000-4000-8000-000000000005';

insert into public.categories (id, name, slug, sort_order, is_active)
values (
  'a3710000-0000-4000-8000-000000000001',
  'Inventory Category',
  'inventory-adj-category',
  370,
  true
);

insert into public.products (
  id, category_id, brand_id, name, slug, status, is_featured, published_at
) values (
  'a3720000-0000-4000-8000-000000000001',
  'a3710000-0000-4000-8000-000000000001',
  null,
  'Inventory Adjust Product',
  'inventory-adjust-product',
  'active',
  false,
  timezone('utc', now())
);

insert into public.product_variants (
  id, product_id, sku, name, price, is_default, is_active, sort_order
) values
  (
    'a3730000-0000-4000-8000-000000000001',
    'a3720000-0000-4000-8000-000000000001',
    'INV-ADJ-STOCK',
    'Stocked',
    1000,
    true,
    true,
    0
  ),
  (
    'a3730000-0000-4000-8000-000000000002',
    'a3720000-0000-4000-8000-000000000001',
    'INV-ADJ-MISSING',
    'Missing row',
    1100,
    false,
    true,
    1
  ),
  (
    'a3730000-0000-4000-8000-000000000003',
    'a3720000-0000-4000-8000-000000000001',
    'INV-ADJ-RESERVE',
    'Reserved tight',
    1200,
    false,
    true,
    2
  ),
  (
    'a3730000-0000-4000-8000-000000000004',
    'a3720000-0000-4000-8000-000000000001',
    'INV-ADJ-OVERFLOW',
    'Overflow',
    1300,
    false,
    true,
    3
  );

insert into public.inventory (
  variant_id, quantity_on_hand, quantity_reserved, reorder_level, allow_backorder
) values
  ('a3730000-0000-4000-8000-000000000001', 10, 2, 4, false),
  ('a3730000-0000-4000-8000-000000000003', 5, 4, 1, false),
  ('a3730000-0000-4000-8000-000000000004', 2147483647, 0, 0, false);

do $$
declare
  v_list_sig text := 'public.list_cms_inventory(text, text, text, integer, integer)';
  v_adjust_sig text :=
    'public.adjust_cms_inventory(uuid, text, integer, boolean, text, text)';
  v_volatile "char";
  v_secdef boolean;
  v_config text[];
  v_bad integer;
begin
  select p.provolatile, p.prosecdef, p.proconfig
  into v_volatile, v_secdef, v_config
  from pg_proc p
  where p.oid = v_list_sig::regprocedure;

  if v_volatile is distinct from 's' then
    raise exception 'FAIL: list_cms_inventory is not STABLE';
  end if;
  if v_secdef is not false then
    raise exception 'FAIL: list_cms_inventory is not SECURITY INVOKER';
  end if;
  if v_config is null
     or not exists (
       select 1
       from unnest(v_config) as cfg(val)
       where cfg.val in ('search_path=', 'search_path=""')
     )
  then
    raise exception 'FAIL: list_cms_inventory search_path is not empty';
  end if;

  select p.provolatile, p.prosecdef, p.proconfig
  into v_volatile, v_secdef, v_config
  from pg_proc p
  where p.oid = v_adjust_sig::regprocedure;

  if v_volatile is distinct from 'v' then
    raise exception 'FAIL: adjust_cms_inventory is not VOLATILE';
  end if;
  if v_secdef is not true then
    raise exception 'FAIL: adjust_cms_inventory is not SECURITY DEFINER';
  end if;
  if v_config is null
     or not exists (
       select 1
       from unnest(v_config) as cfg(val)
       where cfg.val in ('search_path=', 'search_path=""')
     )
  then
    raise exception 'FAIL: adjust_cms_inventory search_path is not empty';
  end if;

  select count(*) into v_bad
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  join unnest(p.proargnames) as args(argname) on true
  where n.nspname = 'public'
    and p.proname in ('list_cms_inventory', 'adjust_cms_inventory')
    and args.argname in ('cost_price', 'barcode');
  if v_bad <> 0 then
    raise exception 'FAIL: inventory RPCs expose cost_price or barcode';
  end if;

  select count(*) into v_bad
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  join unnest(p.proargnames) with ordinality as args(argname, ord) on true
  where n.nspname = 'public'
    and p.proname = 'adjust_cms_inventory'
    and args.ord > p.pronargs
    and args.argname not in (
      'variant_id',
      'quantity_on_hand',
      'quantity_reserved',
      'reorder_level',
      'allow_backorder'
    );
  if v_bad <> 0 then
    raise exception 'FAIL: adjust_cms_inventory return is not minimal';
  end if;

  if has_function_privilege('public', v_list_sig, 'EXECUTE')
     or has_function_privilege('anon', v_list_sig, 'EXECUTE')
  then
    raise exception 'FAIL: list_cms_inventory EXECUTE too broad';
  end if;
  if has_function_privilege('public', v_adjust_sig, 'EXECUTE')
     or has_function_privilege('anon', v_adjust_sig, 'EXECUTE')
  then
    raise exception 'FAIL: adjust_cms_inventory EXECUTE too broad';
  end if;

  raise notice 'OK: inventory RPC definitions and grants';
end $$;

do $$
declare
  v_list text :=
    $q$select variant_id from public.list_cms_inventory('', 'all', 'updated_desc', 0, 20)$q$;
  v_adjust text :=
    $q$select variant_id from public.adjust_cms_inventory(
      'a3730000-0000-4000-8000-000000000001'::uuid,
      'add_stock', 1, null, 'received', null
    )$q$;
  v_customer uuid := 'a3700000-0000-4000-8000-000000000001';
  v_inactive uuid := 'a3700000-0000-4000-8000-000000000004';
  v_missing uuid := 'a3700000-0000-4000-8000-000000000005';
begin
  execute 'set local role anon';
  perform pg_temp.inv_assert_execute_denied('anon list_cms_inventory', v_list);
  perform pg_temp.inv_assert_execute_denied('anon adjust_cms_inventory', v_adjust);
  execute 'reset role';

  perform pg_temp.inv_set_auth(v_customer);
  perform pg_temp.inv_assert_authz_denied('customer list_cms_inventory', v_list);
  perform pg_temp.inv_assert_authz_denied('customer adjust_cms_inventory', v_adjust);
  perform pg_temp.inv_clear_auth();

  perform pg_temp.inv_set_auth(v_inactive);
  perform pg_temp.inv_assert_authz_denied('inactive list_cms_inventory', v_list);
  perform pg_temp.inv_assert_authz_denied('inactive adjust_cms_inventory', v_adjust);
  perform pg_temp.inv_clear_auth();

  perform pg_temp.inv_set_auth(v_missing);
  perform pg_temp.inv_assert_authz_denied('missing profile list', v_list);
  perform pg_temp.inv_assert_authz_denied('missing profile adjust', v_adjust);
  perform pg_temp.inv_clear_auth();

  perform set_config('request.jwt.claim.sub', v_customer::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', v_customer::text,
      'role', 'authenticated',
      'user_metadata', json_build_object('role', 'admin'),
      'app_metadata', json_build_object('role', 'staff')
    )::text,
    true
  );
  execute 'set local role authenticated';
  perform pg_temp.inv_assert_authz_denied('forged list_cms_inventory', v_list);
  perform pg_temp.inv_assert_authz_denied('forged adjust_cms_inventory', v_adjust);
  perform pg_temp.inv_clear_auth();

  raise notice 'OK: inventory RPC denial matrix';
end $$;

do $$
declare
  v_staff uuid := 'a3700000-0000-4000-8000-000000000002';
  v_admin uuid := 'a3700000-0000-4000-8000-000000000003';
  v_stock uuid := 'a3730000-0000-4000-8000-000000000001';
  v_missing uuid := 'a3730000-0000-4000-8000-000000000002';
  v_reserve uuid := 'a3730000-0000-4000-8000-000000000003';
  v_overflow uuid := 'a3730000-0000-4000-8000-000000000004';
  v_unknown uuid := 'a3790000-0000-4000-8000-000000000099';
  v_on_hand integer;
  v_reserved integer;
  v_reorder integer;
  v_backorder boolean;
  v_history integer;
  v_count integer;
  v_available integer;
  v_state text;
  v_returned uuid;
begin
  perform pg_temp.inv_set_auth(v_staff);

  select q.variant_id, q.quantity_on_hand, q.quantity_reserved,
         q.reorder_level, q.allow_backorder
  into v_returned, v_on_hand, v_reserved, v_reorder, v_backorder
  from public.adjust_cms_inventory(
    v_stock, 'add_stock', 3, null, 'received', ' inbound pallet '
  ) as q;

  if v_returned is distinct from v_stock
     or v_on_hand <> 13
     or v_reserved <> 2
     or v_reorder <> 4
     or v_backorder is not false
  then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: staff add_stock result incorrect';
  end if;

  select quantity_on_hand, quantity_reserved
  into v_on_hand, v_reserved
  from public.inventory where variant_id = v_stock;
  if v_on_hand <> 13 or v_reserved <> 2 then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: add_stock did not persist';
  end if;

  perform public.adjust_cms_inventory(
    v_stock, 'remove_stock', 1, null, 'damaged', null
  );
  select quantity_on_hand into v_on_hand
  from public.inventory where variant_id = v_stock;
  if v_on_hand <> 12 then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: remove_stock did not persist';
  end if;

  perform public.adjust_cms_inventory(
    v_stock, 'set_on_hand', 20, null, 'count_correction', null
  );
  perform public.adjust_cms_inventory(
    v_stock, 'set_reorder_level', 6, null, 'other', 'raise floor'
  );
  perform public.adjust_cms_inventory(
    v_stock, 'set_allow_backorder', null, true, 'other', null
  );

  select quantity_on_hand, reorder_level, allow_backorder
  into v_on_hand, v_reorder, v_backorder
  from public.inventory where variant_id = v_stock;
  if v_on_hand <> 20 or v_reorder <> 6 or v_backorder is not true then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: set operations did not persist';
  end if;

  select count(*) into v_history
  from public.inventory_history
  where variant_id = v_stock
    and actor_id = v_staff;
  if v_history <> 5 then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: staff history count=%', v_history;
  end if;

  select q.quantity_on_hand, q.quantity_reserved
  into v_on_hand, v_reserved
  from public.adjust_cms_inventory(
    v_missing, 'add_stock', 7, null, 'received', null
  ) as q;
  if v_on_hand <> 7 or v_reserved <> 0 then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: missing inventory row was not created';
  end if;

  perform pg_temp.inv_assert_not_found(
    'unknown variant',
    format(
      $q$select variant_id from public.adjust_cms_inventory(
        %L::uuid, 'add_stock', 1, null, 'received', null
      )$q$,
      v_unknown
    )
  );
  perform pg_temp.inv_assert_not_found(
    'cross id product-as-variant',
    $q$select variant_id from public.adjust_cms_inventory(
      'a3720000-0000-4000-8000-000000000001'::uuid,
      'add_stock', 1, null, 'received', null
    )$q$
  );

  perform pg_temp.inv_assert_invalid(
    'negative add',
    format(
      $q$select variant_id from public.adjust_cms_inventory(
        %L::uuid, 'add_stock', -1, null, 'received', null
      )$q$,
      v_stock
    )
  );
  perform pg_temp.inv_assert_invalid(
    'zero remove',
    format(
      $q$select variant_id from public.adjust_cms_inventory(
        %L::uuid, 'remove_stock', 0, null, 'damaged', null
      )$q$,
      v_stock
    )
  );
  perform pg_temp.inv_assert_invalid(
    'unknown reason',
    format(
      $q$select variant_id from public.adjust_cms_inventory(
        %L::uuid, 'add_stock', 1, null, 'not-a-reason', null
      )$q$,
      v_stock
    )
  );
  perform pg_temp.inv_assert_invalid(
    'quantity with backorder op',
    format(
      $q$select variant_id from public.adjust_cms_inventory(
        %L::uuid, 'set_allow_backorder', 1, true, 'other', null
      )$q$,
      v_stock
    )
  );
  perform pg_temp.inv_assert_invalid(
    'overflow add',
    format(
      $q$select variant_id from public.adjust_cms_inventory(
        %L::uuid, 'add_stock', 1, null, 'received', null
      )$q$,
      v_overflow
    )
  );

  select quantity_on_hand into v_on_hand
  from public.inventory where variant_id = v_overflow;
  if v_on_hand <> 2147483647 then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: overflow mutated on-hand';
  end if;

  perform pg_temp.inv_assert_invalid(
    'remove below reserved',
    format(
      $q$select variant_id from public.adjust_cms_inventory(
        %L::uuid, 'remove_stock', 2, null, 'damaged', null
      )$q$,
      v_reserve
    )
  );
  perform pg_temp.inv_assert_invalid(
    'set on-hand below reserved',
    format(
      $q$select variant_id from public.adjust_cms_inventory(
        %L::uuid, 'set_on_hand', 3, null, 'count_correction', null
      )$q$,
      v_reserve
    )
  );

  select quantity_on_hand, quantity_reserved into v_on_hand, v_reserved
  from public.inventory where variant_id = v_reserve;
  if v_on_hand <> 5 or v_reserved <> 4 then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: reserved invariant mutated on rejection';
  end if;

  select count(*) into v_history
  from public.inventory_history where variant_id = v_reserve;
  if v_history <> 0 then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: rejected adjust wrote history';
  end if;

  perform public.adjust_cms_inventory(
    v_reserve, 'set_allow_backorder', null, true, 'other', null
  );
  perform public.adjust_cms_inventory(
    v_reserve, 'set_on_hand', 3, null, 'count_correction', null
  );
  select quantity_on_hand, quantity_reserved, allow_backorder
  into v_on_hand, v_reserved, v_backorder
  from public.inventory where variant_id = v_reserve;
  if v_on_hand <> 3 or v_reserved <> 4 or v_backorder is not true then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: backorder set_on_hand below reserved failed';
  end if;

  perform pg_temp.inv_assert_invalid(
    'disable backorder while reserved exceeds on-hand',
    format(
      $q$select variant_id from public.adjust_cms_inventory(
        %L::uuid, 'set_allow_backorder', null, false, 'other', null
      )$q$,
      v_reserve
    )
  );

  select count(*) into v_count
  from public.list_cms_inventory('INV-ADJ-STOCK', 'all', 'sku_asc', 0, 20);
  if v_count < 1 then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: list search missed SKU';
  end if;

  select q.stock_state, q.quantity_available
  into v_state, v_available
  from public.list_cms_inventory('INV-ADJ-STOCK', 'all', 'sku_asc', 0, 20) as q
  where q.variant_id = v_stock;
  if v_state is null or v_available is null then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: list did not return stock fields';
  end if;

  perform pg_temp.inv_assert_invalid(
    'list bad stock',
    $q$select variant_id from public.list_cms_inventory('', 'nope', 'updated_desc', 0, 20)$q$
  );
  perform pg_temp.inv_assert_invalid(
    'list bad limit',
    $q$select variant_id from public.list_cms_inventory('', 'all', 'updated_desc', 0, 51)$q$
  );

  perform pg_temp.inv_clear_auth();

  perform pg_temp.inv_set_auth(v_admin);
  perform public.adjust_cms_inventory(
    v_stock, 'add_stock', 1, null, 'returned', null
  );
  select quantity_on_hand into v_on_hand
  from public.inventory where variant_id = v_stock;
  if v_on_hand <> 21 then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: admin add_stock did not persist';
  end if;
  perform pg_temp.inv_clear_auth();

  raise notice 'OK: staff/admin inventory adjust and list behavior';
exception
  when others then
    perform pg_temp.inv_clear_auth();
    raise;
end $$;

do $$
declare
  v_staff uuid := 'a3700000-0000-4000-8000-000000000002';
  v_customer uuid := 'a3700000-0000-4000-8000-000000000001';
  v_stock uuid := 'a3730000-0000-4000-8000-000000000001';
  v_history_id uuid;
  v_denied boolean;
  v_count integer;
begin
  perform pg_temp.inv_set_auth(v_staff);
  select id into v_history_id
  from public.inventory_history
  where variant_id = v_stock
  order by created_at desc
  limit 1;
  if v_history_id is null then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: staff cannot SELECT inventory_history';
  end if;

  v_denied := false;
  begin
    insert into public.inventory_history (
      variant_id, actor_id, operation, reason,
      quantity_on_hand_before, quantity_on_hand_after,
      quantity_reserved_before, quantity_reserved_after,
      reorder_level_before, reorder_level_after,
      allow_backorder_before, allow_backorder_after
    ) values (
      v_stock, v_staff, 'add_stock', 'received',
      0, 1, 0, 0, 0, 0, false, false
    );
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate in ('42501', '42501') then
        v_denied := true;
      else
        perform pg_temp.inv_clear_auth();
        raise exception
          'FAIL: staff history INSERT unexpected SQLSTATE %', sqlstate;
      end if;
  end;
  if not v_denied then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: staff direct history INSERT succeeded';
  end if;

  v_denied := false;
  begin
    update public.inventory_history
    set reason = 'lost'
    where id = v_history_id;
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate in ('42501', '55000') then
        v_denied := true;
      else
        perform pg_temp.inv_clear_auth();
        raise exception
          'FAIL: staff history UPDATE unexpected SQLSTATE %', sqlstate;
      end if;
  end;
  if not v_denied then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: staff direct history UPDATE succeeded';
  end if;

  v_denied := false;
  begin
    delete from public.inventory_history where id = v_history_id;
  exception
    when insufficient_privilege then
      v_denied := true;
    when others then
      if sqlstate in ('42501', '55000') then
        v_denied := true;
      else
        perform pg_temp.inv_clear_auth();
        raise exception
          'FAIL: staff history DELETE unexpected SQLSTATE %', sqlstate;
      end if;
  end;
  if not v_denied then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: staff direct history DELETE succeeded';
  end if;
  perform pg_temp.inv_clear_auth();

  perform pg_temp.inv_set_auth(v_customer);
  select count(*) into v_count from public.inventory_history;
  if v_count <> 0 then
    perform pg_temp.inv_clear_auth();
    raise exception 'FAIL: customer can SELECT inventory_history';
  end if;
  perform pg_temp.inv_clear_auth();

  execute 'reset role';
  v_denied := false;
  begin
    update public.inventory_history
    set note = 'tamper'
    where id = v_history_id;
  exception
    when others then
      if sqlstate = '55000' then
        v_denied := true;
      else
        raise exception
          'FAIL: owner history UPDATE unexpected SQLSTATE %', sqlstate;
      end if;
  end;
  if not v_denied then
    raise exception 'FAIL: owner history UPDATE succeeded';
  end if;

  v_denied := false;
  begin
    delete from public.inventory_history where id = v_history_id;
  exception
    when others then
      if sqlstate = '55000' then
        v_denied := true;
      else
        raise exception
          'FAIL: owner history DELETE unexpected SQLSTATE %', sqlstate;
      end if;
  end;
  if not v_denied then
    raise exception 'FAIL: owner history DELETE succeeded';
  end if;

  raise notice 'OK: inventory_history immutability';
end $$;

rollback;

\echo '== done =='
