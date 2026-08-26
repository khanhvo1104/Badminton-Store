-- TASK-047: Emit owner-scoped order_update notifications from trusted order writers.
-- Inserts run inside the same transaction as checkout_cod / transition_cms_order_status;
-- notification constraint violations fail-closed and roll back the writer.

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
  v_order_number text;
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

  select o.order_number
  into v_order_number
  from public.orders o
  where o.id = v_order_id;

  if v_order_number is null or pg_catalog.btrim(v_order_number) = '' then
    raise exception 'checkout_cod order_number missing after insert'
      using errcode = 'P0001';
  end if;

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    payload
  )
  values (
    v_user_id,
    'order_update',
    'Order placed',
    'Your order ' || v_order_number || ' has been placed.',
    pg_catalog.jsonb_build_object(
      'order_id', v_order_id::text,
      'order_number', v_order_number,
      'event', 'order_placed',
      'status', 'pending'
    )
  );

  return v_order_id;
end;
$$;

comment on function public.checkout_cod(uuid, text) is
  'Authenticated COD checkout. Reprices from product_variants.price, reserves '
  'inventory, inserts order + item snapshots, converts the active cart, and '
  'emits one owner-scoped order_update notification. SECURITY DEFINER with '
  'empty search_path. Returns only the new order UUID.';

revoke all on function public.checkout_cod(uuid, text) from public;
revoke all on function public.checkout_cod(uuid, text) from anon;
grant execute on function public.checkout_cod(uuid, text)
  to authenticated, service_role;

create or replace function public.transition_cms_order_status(
  p_order_id uuid,
  p_to_status text,
  p_note text default null
)
returns table (
  order_id uuid
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_from_status text;
  v_to_status text;
  v_order_user_id uuid;
  v_order_number text;
  v_note text;
  v_history_id uuid;
  v_item record;
  v_reserved integer;
  v_on_hand integer;
  v_needs_release boolean;
  v_needs_consume boolean;
begin
  if not public.is_staff_or_admin() then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  v_actor := auth.uid();
  if v_actor is null then
    raise exception 'not authorized'
      using errcode = '42501';
  end if;

  if p_order_id is null or p_to_status is null then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_to_status := pg_catalog.btrim(p_to_status);
  if v_to_status not in (
    'pending',
    'confirmed',
    'preparing',
    'shipping',
    'delivered',
    'cancelled',
    'returned'
  ) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_note := nullif(pg_catalog.btrim(coalesce(p_note, '')), '');
  if v_note is not null then
    v_note := pg_catalog.regexp_replace(v_note, '[[:space:]]+', ' ', 'g');
    if pg_catalog.char_length(v_note) > 500 then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;
  end if;

  select
    order_row.status,
    order_row.user_id,
    order_row.order_number
  into
    v_from_status,
    v_order_user_id,
    v_order_number
  from public.orders as order_row
  where order_row.id = p_order_id
  for update of order_row;

  if not found then
    raise exception 'not found'
      using errcode = 'P0002';
  end if;

  if v_from_status is not distinct from v_to_status then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if not (
    (v_from_status = 'pending' and v_to_status in ('confirmed', 'cancelled'))
    or (v_from_status = 'confirmed' and v_to_status in ('preparing', 'cancelled'))
    or (v_from_status = 'preparing' and v_to_status in ('shipping', 'cancelled'))
    or (v_from_status = 'shipping' and v_to_status = 'delivered')
    or (v_from_status = 'delivered' and v_to_status = 'returned')
  ) then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  v_needs_release := (
    v_to_status = 'cancelled'
    and v_from_status in ('pending', 'confirmed', 'preparing')
  );
  v_needs_consume := (v_to_status = 'delivered');

  if v_needs_release or v_needs_consume then
    if exists (
      select 1
      from public.order_items as item_row
      where item_row.order_id = p_order_id
        and item_row.variant_id is null
    ) then
      raise exception 'invalid request'
        using errcode = '22023';
    end if;

    for v_item in
      select
        item_row.variant_id,
        pg_catalog.sum(item_row.quantity)::integer as quantity
      from public.order_items as item_row
      where item_row.order_id = p_order_id
      group by item_row.variant_id
      order by item_row.variant_id asc
    loop
      select
        inventory_row.quantity_reserved,
        inventory_row.quantity_on_hand
      into v_reserved, v_on_hand
      from public.inventory as inventory_row
      where inventory_row.variant_id = v_item.variant_id
      for update of inventory_row;

      if not found then
        raise exception 'invalid request'
          using errcode = '22023';
      end if;

      if v_reserved < v_item.quantity then
        raise exception 'invalid request'
          using errcode = '22023';
      end if;

      if v_needs_consume and v_on_hand < v_item.quantity then
        raise exception 'invalid request'
          using errcode = '22023';
      end if;

      if v_needs_release then
        update public.inventory as inventory_row
        set quantity_reserved = inventory_row.quantity_reserved - v_item.quantity
        where inventory_row.variant_id = v_item.variant_id
          and inventory_row.quantity_reserved = v_reserved;

        if not found then
          raise exception 'invalid request'
            using errcode = '22023';
        end if;
      else
        update public.inventory as inventory_row
        set
          quantity_reserved = inventory_row.quantity_reserved - v_item.quantity,
          quantity_on_hand = inventory_row.quantity_on_hand - v_item.quantity
        where inventory_row.variant_id = v_item.variant_id
          and inventory_row.quantity_reserved = v_reserved
          and inventory_row.quantity_on_hand = v_on_hand;

        if not found then
          raise exception 'invalid request'
            using errcode = '22023';
        end if;
      end if;
    end loop;
  end if;

  update public.orders as order_row
  set
    status = v_to_status,
    cancelled_at = case
      when v_to_status = 'cancelled' then timezone('utc', now())
      else order_row.cancelled_at
    end
  where order_row.id = p_order_id
    and order_row.status = v_from_status;

  if not found then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  select history_row.id
  into v_history_id
  from public.order_status_history as history_row
  where history_row.order_id = p_order_id
    and history_row.from_status is not distinct from v_from_status
    and history_row.to_status = v_to_status
    and history_row.changed_by is not distinct from v_actor
  order by history_row.created_at desc, history_row.id desc
  limit 1;

  if v_history_id is null then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if v_note is not null then
    update public.order_status_history as history_row
    set note = v_note
    where history_row.id = v_history_id
      and history_row.note is null;
  end if;

  if v_order_user_id is null then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  if v_order_number is null or pg_catalog.btrim(v_order_number) = '' then
    raise exception 'invalid request'
      using errcode = '22023';
  end if;

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    payload
  )
  values (
    v_order_user_id,
    'order_update',
    'Order update',
    'Your order ' || v_order_number || ' is now ' || v_to_status || '.',
    pg_catalog.jsonb_build_object(
      'order_id', p_order_id::text,
      'order_number', v_order_number,
      'event', 'status_changed',
      'status', v_to_status,
      'from_status', v_from_status,
      'to_status', v_to_status
    )
  );

  return query
  select p_order_id;
end;
$$;

comment on function public.transition_cms_order_status(
  uuid, text, text
) is
  'CMS order status transition. SECURITY DEFINER, VOLATILE, empty search_path. '
  'Justified because authenticated UPDATE on public.orders is revoked; status '
  'changes must not be client-writable. Authorizes via is_staff_or_admin() and '
  'records auth.uid() as actor. Locks the order row, validates the transition '
  'graph, releases reservations on pre-shipping cancel, consumes reserved and '
  'on-hand on delivered, leaves returned without restock, updates status and '
  'cancelled_at, relies on orders_record_status_history for exactly one '
  'history row (optional note stamped afterward), and emits one owner-scoped '
  'order_update notification. Returns only order_id. EXECUTE granted to '
  'authenticated and service_role only.';

revoke all on function public.transition_cms_order_status(
  uuid, text, text
) from public;
revoke all on function public.transition_cms_order_status(
  uuid, text, text
) from anon;
revoke all on function public.transition_cms_order_status(
  uuid, text, text
) from authenticated;
revoke all on function public.transition_cms_order_status(
  uuid, text, text
) from service_role;

grant execute on function public.transition_cms_order_status(
  uuid, text, text
) to authenticated, service_role;

revoke all on function public.record_order_status_change() from public;
revoke all on function public.record_order_status_change() from anon;
revoke all on function public.record_order_status_change() from authenticated;
grant execute on function public.record_order_status_change() to service_role;
