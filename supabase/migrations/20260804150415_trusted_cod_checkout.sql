-- Trusted MVP COD checkout: reprice, reserve stock, snapshot order, convert cart.
-- Callable only by authenticated users (and service_role for ops); auth.uid() is
-- the sole customer identity. Never trust client totals, prices, or stock state.

-- Prevent phantom cart_items inserts that race with checkout_cod:
-- a concurrent INSERT can block on the cart row lock held by checkout, then
-- resume after conversion and append a line that was never ordered. RLS
-- WITH CHECK alone is not enough under READ COMMITTED statement snapshots.
-- This trigger re-locks the parent cart and rechecks status after waiting.
create or replace function public.cart_items_enforce_active_cart()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_status text;
begin
  select c.status
  into v_status
  from public.carts c
  where c.id = new.cart_id
  for update of c;

  if v_status is null then
    raise exception 'cart_items require an existing cart'
      using errcode = 'P0002';
  end if;

  if v_status is distinct from 'active' then
    raise exception 'cart_items require an active cart'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

comment on function public.cart_items_enforce_active_cart() is
  'Rejects cart_items INSERT/UPDATE when the parent cart is missing or not '
  'active. Takes FOR UPDATE on the cart so mutations serialize with checkout_cod '
  'and re-evaluate status after waiting (closes the converted-cart phantom race).';

revoke all on function public.cart_items_enforce_active_cart() from public;
revoke all on function public.cart_items_enforce_active_cart() from anon;
grant execute on function public.cart_items_enforce_active_cart()
  to authenticated, service_role;

drop trigger if exists cart_items_enforce_active_cart on public.cart_items;
create trigger cart_items_enforce_active_cart
before insert or update on public.cart_items
for each row
execute function public.cart_items_enforce_active_cart();

create or replace function public.checkout_cod(
  p_shipping_address_id uuid,
  p_customer_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_profile_id uuid;
  v_cart_id uuid;
  v_currency_code text;
  v_recipient_name text;
  v_recipient_phone text;
  v_address_snapshot jsonb;
  v_customer_note text;
  v_cart_item_count integer;
  v_valid_line_count integer;
  v_subtotal numeric(14, 2) := 0;
  v_discount_total numeric(14, 2) := 0;
  v_shipping_fee numeric(14, 2) := 0;
  v_grand_total numeric(14, 2);
  v_order_id uuid;
  v_updated integer;
  v_line record;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'checkout_cod requires an authenticated user'
      using errcode = '42501';
  end if;

  select p.id
  into v_profile_id
  from public.profiles p
  where p.id = v_user_id
    and p.is_active = true;

  if v_profile_id is null then
    raise exception 'checkout_cod requires an active profile'
      using errcode = '42501';
  end if;

  select
    a.recipient_name,
    a.phone_number,
    pg_catalog.jsonb_build_object(
      'id', a.id,
      'recipient_name', a.recipient_name,
      'phone_number', a.phone_number,
      'province_code', a.province_code,
      'province_name', a.province_name,
      'district_code', a.district_code,
      'district_name', a.district_name,
      'ward_code', a.ward_code,
      'ward_name', a.ward_name,
      'street_address', a.street_address,
      'address_note', a.address_note
    )
  into
    v_recipient_name,
    v_recipient_phone,
    v_address_snapshot
  from public.addresses a
  where a.id = p_shipping_address_id
    and a.user_id = v_user_id;

  if v_recipient_name is null then
    raise exception 'checkout_cod shipping address not found'
      using errcode = 'P0002';
  end if;

  v_customer_note := nullif(
    pg_catalog.btrim(coalesce(p_customer_note, '')),
    ''
  );

  select c.id, c.currency_code
  into v_cart_id, v_currency_code
  from public.carts c
  where c.user_id = v_user_id
    and c.guest_token is null
    and c.status = 'active'
  for update of c;

  if v_cart_id is null then
    raise exception 'checkout_cod requires an active cart'
      using errcode = 'P0002';
  end if;

  if v_currency_code is distinct from 'VND' then
    raise exception 'checkout_cod supports VND carts only'
      using errcode = '22023';
  end if;

  -- Lock existing cart lines deterministically (variant_id, then item id).
  perform 1
  from public.cart_items ci
  where ci.cart_id = v_cart_id
  order by ci.variant_id, ci.id
  for update of ci;

  select count(*)::integer
  into v_cart_item_count
  from public.cart_items ci
  where ci.cart_id = v_cart_id;

  if v_cart_item_count = 0 then
    raise exception 'checkout_cod cart is empty'
      using errcode = 'P0002';
  end if;

  select count(*)::integer
  into v_valid_line_count
  from public.cart_items ci
  join public.product_variants pv on pv.id = ci.variant_id
  join public.products p on p.id = pv.product_id
  join public.inventory i on i.variant_id = pv.id
  where ci.cart_id = v_cart_id
    and ci.quantity > 0
    and pv.is_active = true
    and p.status = 'active';

  if v_valid_line_count <> v_cart_item_count then
    raise exception 'checkout_cod cart contains invalid catalog or inventory rows'
      using errcode = '22023';
  end if;

  -- Lock inventory rows in ascending variant_id order before stock checks.
  perform 1
  from public.inventory i
  where i.variant_id in (
    select ci.variant_id
    from public.cart_items ci
    where ci.cart_id = v_cart_id
  )
  order by i.variant_id
  for update of i;

  for v_line in
    select
      ci.variant_id,
      ci.quantity,
      i.allow_backorder,
      i.quantity_on_hand,
      i.quantity_reserved,
      pv.price as unit_price,
      (pv.price * ci.quantity)::numeric(14, 2) as line_total
    from public.cart_items ci
    join public.product_variants pv on pv.id = ci.variant_id
    join public.inventory i on i.variant_id = pv.id
    where ci.cart_id = v_cart_id
    order by ci.variant_id, ci.id
  loop
    if not v_line.allow_backorder
       and (v_line.quantity_on_hand - v_line.quantity_reserved) < v_line.quantity
    then
      raise exception 'checkout_cod insufficient stock for variant %',
        v_line.variant_id
        using errcode = 'P0001';
    end if;

    v_subtotal := (v_subtotal + v_line.line_total)::numeric(14, 2);
  end loop;

  if v_subtotal is null or v_subtotal < 0 then
    raise exception 'checkout_cod computed an invalid subtotal'
      using errcode = '22023';
  end if;

  v_grand_total := (v_subtotal - v_discount_total + v_shipping_fee)::numeric(14, 2);

  if v_grand_total is distinct from v_subtotal then
    raise exception 'checkout_cod grand_total math failed'
      using errcode = '22023';
  end if;

  insert into public.orders (
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
    customer_note,
    recipient_name,
    recipient_phone,
    shipping_address
  )
  values (
    '',
    v_user_id,
    'pending',
    'cod',
    'unpaid',
    v_currency_code,
    v_subtotal,
    v_discount_total,
    v_shipping_fee,
    v_grand_total,
    v_customer_note,
    v_recipient_name,
    v_recipient_phone,
    v_address_snapshot
  )
  returning id into v_order_id;

  insert into public.order_items (
    order_id,
    product_id,
    variant_id,
    product_name,
    variant_name,
    sku,
    image_path,
    unit_price,
    quantity,
    line_total,
    product_snapshot
  )
  select
    v_order_id,
    p.id,
    pv.id,
    p.name,
    pv.name,
    pv.sku,
    coalesce(
      (
        select pi.storage_path
        from public.product_images pi
        where pi.variant_id = pv.id
          and pi.is_primary = true
        order by pi.sort_order, pi.id
        limit 1
      ),
      (
        select pi.storage_path
        from public.product_images pi
        where pi.product_id = p.id
          and pi.variant_id is null
          and pi.is_primary = true
        order by pi.sort_order, pi.id
        limit 1
      )
    ),
    pv.price,
    ci.quantity,
    (pv.price * ci.quantity)::numeric(14, 2),
    pg_catalog.jsonb_build_object(
      'product_id', p.id,
      'variant_id', pv.id,
      'product_name', p.name,
      'variant_name', pv.name,
      'sku', pv.sku,
      'slug', p.slug,
      'unit', pv.unit,
      'color_name', pv.color_name,
      'color_hex', pv.color_hex,
      'racket_weight_class', pv.racket_weight_class,
      'grip_size', pv.grip_size,
      'shoe_size', pv.shoe_size,
      'clothing_size', pv.clothing_size,
      'attributes', pv.attributes
    )
  from public.cart_items ci
  join public.product_variants pv on pv.id = ci.variant_id
  join public.products p on p.id = pv.product_id
  where ci.cart_id = v_cart_id
  order by ci.variant_id, ci.id;

  get diagnostics v_updated = row_count;
  if v_updated <> v_cart_item_count then
    raise exception 'checkout_cod failed to insert all order items'
      using errcode = 'P0001';
  end if;

  update public.inventory i
  set quantity_reserved = i.quantity_reserved + ci.quantity
  from public.cart_items ci
  where ci.cart_id = v_cart_id
    and i.variant_id = ci.variant_id;

  get diagnostics v_updated = row_count;
  if v_updated <> v_cart_item_count then
    raise exception 'checkout_cod failed to reserve inventory for all lines'
      using errcode = 'P0001';
  end if;

  update public.carts c
  set status = 'converted'
  where c.id = v_cart_id
    and c.user_id = v_user_id
    and c.status = 'active'
    and c.guest_token is null;

  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    raise exception 'checkout_cod failed to convert active cart'
      using errcode = 'P0001';
  end if;

  return v_order_id;
end;
$$;

comment on function public.checkout_cod(uuid, text) is
  'Authenticated COD checkout. Reprices from product_variants.price, reserves '
  'inventory, inserts order + item snapshots, converts the active cart. '
  'SECURITY DEFINER with empty search_path. Returns only the new order UUID.';

revoke all on function public.checkout_cod(uuid, text) from public;
revoke all on function public.checkout_cod(uuid, text) from anon;
grant execute on function public.checkout_cod(uuid, text)
  to authenticated, service_role;
