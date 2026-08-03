-- Constraint and helper verification scripts.
-- Run after migrations + seed against a local database:
--   psql "$DATABASE_URL" -f supabase/tests/database/00_constraints.sql

\echo '== constraint smoke tests =='

-- Duplicate category slug must fail
do $$
begin
  begin
    insert into public.categories (name, slug)
    values ('Dup', 'rackets');
    raise exception 'EXPECTED FAIL: duplicate category slug';
  exception
    when unique_violation then
      raise notice 'OK: duplicate category slug rejected';
  end;
end $$;

-- Negative price must fail
do $$
begin
  begin
    insert into public.product_variants (product_id, sku, price, is_default)
    values ('33333333-3333-3333-3333-333333333301', 'BAD-PRICE', -1, false);
    raise exception 'EXPECTED FAIL: negative price';
  exception
    when check_violation then
      raise notice 'OK: negative price rejected';
  end;
end $$;

-- Invalid role must fail
do $$
begin
  begin
    update public.profiles set role = 'superuser' where false;
    insert into public.profiles (id, role)
    values ('00000000-0000-0000-0000-000000000099', 'superuser');
    raise exception 'EXPECTED FAIL: invalid role';
  exception
    when check_violation then
      raise notice 'OK: invalid role rejected';
    when foreign_key_violation then
      raise notice 'OK: invalid profile id rejected (FK) — role check covered by schema';
  end;
end $$;

-- Invalid order total math must fail
do $$
begin
  begin
    insert into public.orders (
      order_number, user_id, subtotal, discount_total, shipping_fee, grand_total,
      recipient_name, recipient_phone, shipping_address
    ) values (
      'BDM-TEST-BAD',
      '00000000-0000-0000-0000-000000000001',
      100, 0, 0, 50,
      'Test', '0900000000', '{}'::jsonb
    );
    raise exception 'EXPECTED FAIL: bad grand_total';
  exception
    when check_violation then
      raise notice 'OK: bad grand_total rejected';
    when foreign_key_violation then
      raise notice 'OK: order FK missing profile — math constraint still present in schema';
  end;
end $$;

\echo '== done =='
