-- Row Level Security for all application tables.

alter table public.profiles enable row level security;
alter table public.addresses enable row level security;
alter table public.categories enable row level security;
alter table public.brands enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.product_images enable row level security;
alter table public.inventory enable row level security;
alter table public.favorites enable row level security;
alter table public.carts enable row level security;
alter table public.cart_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;

-- ========================= profiles =========================
create policy profiles_select_own_or_staff
  on public.profiles for select
  to authenticated
  using (id = auth.uid() or public.is_staff_or_admin());

comment on policy profiles_select_own_or_staff on public.profiles is
  'Customers read self; staff/admin may read all profiles.';

create policy profiles_update_own_safe
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

comment on policy profiles_update_own_safe on public.profiles is
  'Customers update own profile. Role/is_active locked by trigger.';

create policy profiles_staff_update
  on public.profiles for update
  to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

-- ========================= addresses =========================
create policy addresses_select_own
  on public.addresses for select
  to authenticated
  using (user_id = auth.uid() or public.is_staff_or_admin());

create policy addresses_insert_own
  on public.addresses for insert
  to authenticated
  with check (user_id = auth.uid());

create policy addresses_update_own
  on public.addresses for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy addresses_delete_own
  on public.addresses for delete
  to authenticated
  using (user_id = auth.uid());

-- ========================= categories =========================
create policy categories_select_active_or_staff
  on public.categories for select
  to anon, authenticated
  using (is_active = true or public.is_staff_or_admin());

create policy categories_staff_write
  on public.categories for all
  to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

-- ========================= brands =========================
create policy brands_select_active_or_staff
  on public.brands for select
  to anon, authenticated
  using (is_active = true or public.is_staff_or_admin());

create policy brands_staff_write
  on public.brands for all
  to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

-- ========================= products =========================
create policy products_select_active_or_staff
  on public.products for select
  to anon, authenticated
  using (status = 'active' or public.is_staff_or_admin());

create policy products_staff_write
  on public.products for all
  to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

-- ========================= product_variants =========================
create policy product_variants_select_active_public
  on public.product_variants for select
  to anon, authenticated
  using (
    (
      is_active = true
      and exists (
        select 1
        from public.products p
        where p.id = product_id
          and p.status = 'active'
      )
    )
    or public.is_staff_or_admin()
  );

create policy product_variants_staff_write
  on public.product_variants for all
  to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

-- ========================= product_images =========================
create policy product_images_select_public
  on public.product_images for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.products p
      where p.id = product_id
        and (p.status = 'active' or public.is_staff_or_admin())
    )
  );

create policy product_images_staff_write
  on public.product_images for all
  to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

-- ========================= inventory =========================
-- No direct public select on raw inventory. Use inventory_availability view.
create policy inventory_staff_select
  on public.inventory for select
  to authenticated
  using (public.is_staff_or_admin());

create policy inventory_staff_write
  on public.inventory for all
  to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

-- Grant anon/authenticated select on safe view (invokes underlying RLS on inventory).
-- Because inventory has no anon SELECT policy, security_invoker view would hide
-- stock from public. Provide a SECURITY DEFINER RPC for public availability instead
-- (defined in catalog_views migration). Keep raw inventory staff-only.

-- ========================= favorites =========================
create policy favorites_select_own
  on public.favorites for select
  to authenticated
  using (user_id = auth.uid());

create policy favorites_insert_own
  on public.favorites for insert
  to authenticated
  with check (user_id = auth.uid());

create policy favorites_delete_own
  on public.favorites for delete
  to authenticated
  using (user_id = auth.uid());

-- ========================= carts =========================
create policy carts_select_own
  on public.carts for select
  to authenticated
  using (user_id = auth.uid() or public.is_staff_or_admin());

create policy carts_insert_own
  on public.carts for insert
  to authenticated
  with check (user_id = auth.uid() and guest_token is null);

create policy carts_update_own
  on public.carts for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and guest_token is null);

create policy carts_delete_own
  on public.carts for delete
  to authenticated
  using (user_id = auth.uid());

-- ========================= cart_items =========================
create policy cart_items_select_own
  on public.cart_items for select
  to authenticated
  using (
    exists (
      select 1 from public.carts c
      where c.id = cart_id
        and (c.user_id = auth.uid() or public.is_staff_or_admin())
    )
  );

create policy cart_items_insert_own
  on public.cart_items for insert
  to authenticated
  with check (
    exists (
      select 1 from public.carts c
      where c.id = cart_id
        and c.user_id = auth.uid()
        and c.status = 'active'
    )
  );

create policy cart_items_update_own
  on public.cart_items for update
  to authenticated
  using (
    exists (
      select 1 from public.carts c
      where c.id = cart_id and c.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.carts c
      where c.id = cart_id and c.user_id = auth.uid() and c.status = 'active'
    )
  );

create policy cart_items_delete_own
  on public.cart_items for delete
  to authenticated
  using (
    exists (
      select 1 from public.carts c
      where c.id = cart_id and c.user_id = auth.uid()
    )
  );

-- ========================= orders =========================
create policy orders_select_own
  on public.orders for select
  to authenticated
  using (user_id = auth.uid() or public.is_staff_or_admin());

-- No customer insert/update on orders in MVP — trusted checkout RPC later.
create policy orders_staff_update
  on public.orders for update
  to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

create policy orders_staff_insert
  on public.orders for insert
  to authenticated
  with check (public.is_staff_or_admin());

-- ========================= order_items =========================
create policy order_items_select_own
  on public.order_items for select
  to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_id
        and (o.user_id = auth.uid() or public.is_staff_or_admin())
    )
  );

create policy order_items_staff_insert
  on public.order_items for insert
  to authenticated
  with check (public.is_staff_or_admin());

-- ========================= order_status_history =========================
create policy order_status_history_select_own
  on public.order_status_history for select
  to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_id
        and (o.user_id = auth.uid() or public.is_staff_or_admin())
    )
  );

create policy order_status_history_staff_insert
  on public.order_status_history for insert
  to authenticated
  with check (public.is_staff_or_admin());
