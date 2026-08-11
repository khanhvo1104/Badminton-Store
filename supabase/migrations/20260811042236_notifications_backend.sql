-- Private in-app notifications: owner-isolated reads / read-state updates,
-- trusted service_role writes. No client INSERT/DELETE, no SECURITY DEFINER,
-- no Realtime / push / preferences.

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  constraint notifications_type_check
    check (type in ('order_update', 'promotion', 'system', 'stock_alert')),
  constraint notifications_title_check
    check (char_length(trim(title)) > 0),
  constraint notifications_body_check
    check (char_length(trim(body)) > 0),
  constraint notifications_payload_object_check
    check (jsonb_typeof(payload) = 'object')
);

comment on table public.notifications is
  'Private in-app notifications. Content is immutable to customers; only '
  'is_read is customer-writable. Rows cascade-delete with the owner profile. '
  'Trusted backends insert via service_role; Flutter uses publishable/anon key.';

comment on column public.notifications.type is
  'Flutter NotificationType: order_update, promotion, system, stock_alert.';

comment on column public.notifications.payload is
  'Object-only JSON metadata for deep links / context. Never store secrets, '
  'tokens, or privileged credentials.';

comment on column public.notifications.is_read is
  'Customer-controlled read flag. Only column authenticated may UPDATE.';

-- Owner history pagination (newest first, stable id tie-breaker).
-- Leading user_id also indexes the owner FK for cascade/lookups.
create index notifications_user_created_id_idx
  on public.notifications (user_id, created_at desc, id desc);

-- Efficient unread lookups / counts per owner (newest-first, stable id).
create index notifications_user_unread_idx
  on public.notifications (user_id, created_at desc, id desc)
  where is_read = false;

alter table public.notifications enable row level security;

create policy notifications_select_own
  on public.notifications
  for select
  to authenticated
  using (auth.uid() is not null and user_id = auth.uid());

create policy notifications_update_own_read_state
  on public.notifications
  for update
  to authenticated
  using (auth.uid() is not null and user_id = auth.uid())
  with check (auth.uid() is not null and user_id = auth.uid());

-- Explicit least-privilege Data API grants (self-contained; no default
-- privilege broadening, no GRANT ALL for anon/authenticated).
revoke all on table public.notifications from public, anon, authenticated;

grant select on table public.notifications to authenticated;
grant update (is_read) on table public.notifications to authenticated;

grant all on table public.notifications to service_role;
