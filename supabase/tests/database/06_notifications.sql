-- Executable regression: private notifications schema, grants, and RLS
-- (TASK-019).
--
-- Run against an already migrated + seeded disposable local database:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database/06_notifications.sql
--
-- Fixtures run inside a transaction and roll back. Assert only scenario
-- labels/counts — never print JWTs, secrets, keys, or full notification
-- payloads.

\set ON_ERROR_STOP on
\echo '== notifications backend regression =='

begin;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function pg_temp.notif_insert_user(
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
    crypt('notif-test-password', gen_salt('bf')),
    timezone('utc', now()),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    timezone('utc', now()),
    timezone('utc', now())
  );
end;
$$;

create or replace function pg_temp.notif_set_auth(p_user_id uuid)
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

create or replace function pg_temp.notif_set_auth_no_uid()
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

create or replace function pg_temp.notif_set_anon()
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

create or replace function pg_temp.notif_clear_auth()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

create or replace function pg_temp.notif_assert_check_fails(
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
    when check_violation then
      v_denied := true;
    when not_null_violation then
      v_denied := true;
    when others then
      if sqlstate in ('23514', '23502') then
        v_denied := true;
      else
        perform pg_temp.notif_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.notif_clear_auth();
    raise exception 'FAIL: % expected constraint denial', p_label;
  end if;
end;
$$;

create or replace function pg_temp.notif_assert_privilege_error(
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
        perform pg_temp.notif_clear_auth();
        raise exception
          'FAIL: % raised unexpected SQLSTATE %',
          p_label,
          sqlstate;
      end if;
  end;

  if not v_denied then
    perform pg_temp.notif_clear_auth();
    raise exception 'FAIL: % expected privilege denial (42501)', p_label;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fixtures (owner context; rolled back)
-- ---------------------------------------------------------------------------
select pg_temp.notif_insert_user(
  'a1900000-0000-4000-8000-000000000001',
  'notif-customer-a@example.invalid'
);
select pg_temp.notif_insert_user(
  'a1900000-0000-4000-8000-000000000002',
  'notif-customer-b@example.invalid'
);

-- Trusted insert of private notifications for both owners.
insert into public.notifications (
  id, user_id, type, title, body, payload, is_read
) values
  (
    'b1900000-0000-4000-8000-000000000001',
    'a1900000-0000-4000-8000-000000000001',
    'order_update',
    'Order shipped',
    'Your order is on the way.',
    '{"order_id":"demo"}'::jsonb,
    false
  ),
  (
    'b1900000-0000-4000-8000-000000000002',
    'a1900000-0000-4000-8000-000000000001',
    'system',
    'Welcome',
    'Thanks for joining.',
    '{}'::jsonb,
    true
  ),
  (
    'b1900000-0000-4000-8000-000000000003',
    'a1900000-0000-4000-8000-000000000002',
    'promotion',
    'Sale',
    'Limited offer.',
    '{"campaign":"spring"}'::jsonb,
    false
  );

-- ---------------------------------------------------------------------------
-- Index definitions (ordered columns + unread partial predicate)
-- ---------------------------------------------------------------------------
do $$
declare
  v_history text;
  v_unread text;
begin
  select indexdef into v_history
  from pg_indexes
  where schemaname = 'public'
    and tablename = 'notifications'
    and indexname = 'notifications_user_created_id_idx';

  if v_history is null then
    raise exception 'FAIL: notifications_user_created_id_idx missing';
  end if;
  if position(
    '(user_id, created_at DESC, id DESC)' in v_history
  ) = 0 then
    raise exception
      'FAIL: history index columns/directions: %', v_history;
  end if;
  if position('WHERE' in upper(v_history)) > 0 then
    raise exception
      'FAIL: history index must not be partial: %', v_history;
  end if;

  select indexdef into v_unread
  from pg_indexes
  where schemaname = 'public'
    and tablename = 'notifications'
    and indexname = 'notifications_user_unread_idx';

  if v_unread is null then
    raise exception 'FAIL: notifications_user_unread_idx missing';
  end if;
  if position(
    '(user_id, created_at DESC, id DESC)' in v_unread
  ) = 0 then
    raise exception
      'FAIL: unread index columns/directions: %', v_unread;
  end if;
  if position('WHERE (is_read = false)' in v_unread) = 0
     and position('WHERE ((is_read = false))' in v_unread) = 0 then
    raise exception
      'FAIL: unread index predicate is_read = false: %', v_unread;
  end if;

  raise notice 'OK: notifications index definitions';
end $$;

-- ---------------------------------------------------------------------------
-- Schema / constraint proofs (trusted context)
-- ---------------------------------------------------------------------------
do $$
declare
  v_id uuid;
  v_payload jsonb;
  v_is_read boolean;
  v_created timestamptz;
  v_uid uuid := 'a1900000-0000-4000-8000-000000000001';
begin
  raise notice 'OK: notification fixtures inserted';

  perform pg_temp.notif_assert_check_fails(
    'invalid type',
    format(
      $q$insert into public.notifications (user_id, type, title, body)
         values (%L, 'bogus', 'T', 'B')$q$,
      v_uid
    )
  );

  perform pg_temp.notif_assert_check_fails(
    'blank title',
    format(
      $q$insert into public.notifications (user_id, type, title, body)
         values (%L, 'system', '   ', 'Body')$q$,
      v_uid
    )
  );

  perform pg_temp.notif_assert_check_fails(
    'blank body',
    format(
      $q$insert into public.notifications (user_id, type, title, body)
         values (%L, 'system', 'Title', '  ')$q$,
      v_uid
    )
  );

  perform pg_temp.notif_assert_check_fails(
    'array payload',
    format(
      $q$insert into public.notifications
           (user_id, type, title, body, payload)
         values (%L, 'system', 'Title', 'Body', '[1]'::jsonb)$q$,
      v_uid
    )
  );

  perform pg_temp.notif_assert_check_fails(
    'scalar payload',
    format(
      $q$insert into public.notifications
           (user_id, type, title, body, payload)
         values (%L, 'system', 'Title', 'Body', '"x"'::jsonb)$q$,
      v_uid
    )
  );

  perform pg_temp.notif_assert_check_fails(
    'null payload',
    format(
      $q$insert into public.notifications
           (user_id, type, title, body, payload)
         values (%L, 'system', 'Title', 'Body', null)$q$,
      v_uid
    )
  );

  perform pg_temp.notif_assert_check_fails(
    'null title',
    format(
      $q$insert into public.notifications (user_id, type, title, body)
         values (%L, 'system', null, 'Body')$q$,
      v_uid
    )
  );

  perform pg_temp.notif_assert_check_fails(
    'null body',
    format(
      $q$insert into public.notifications (user_id, type, title, body)
         values (%L, 'system', 'Title', null)$q$,
      v_uid
    )
  );

  perform pg_temp.notif_assert_check_fails(
    'null type',
    format(
      $q$insert into public.notifications (user_id, type, title, body)
         values (%L, null, 'Title', 'Body')$q$,
      v_uid
    )
  );

  perform pg_temp.notif_assert_check_fails(
    'null user_id',
    $q$insert into public.notifications (user_id, type, title, body)
       values (null, 'system', 'Title', 'Body')$q$
  );

  insert into public.notifications (user_id, type, title, body)
  values (v_uid, 'stock_alert', 'Back in stock', 'Variant available')
  returning id, payload, is_read, created_at
  into v_id, v_payload, v_is_read, v_created;

  if v_id is null then
    raise exception 'FAIL: default id not generated';
  end if;
  if v_payload is distinct from '{}'::jsonb then
    raise exception 'FAIL: default payload is not empty object';
  end if;
  if v_is_read is distinct from false then
    raise exception 'FAIL: default is_read is not false';
  end if;
  if v_created is null then
    raise exception 'FAIL: default created_at missing';
  end if;
  -- timestamptz column is timezone-aware by type; assert non-null above.

  delete from public.notifications where id = v_id;

  raise notice 'OK: notification constraints and defaults';
end $$;

-- ---------------------------------------------------------------------------
-- Access: anon denial
-- ---------------------------------------------------------------------------
do $$
declare
  v_count integer;
begin
  perform pg_temp.notif_set_anon();

  begin
    select count(*) into v_count from public.notifications;
    raise exception 'FAIL: anon SELECT on notifications succeeded';
  exception
    when insufficient_privilege then
      null;
    when others then
      if sqlstate <> '42501' then
        perform pg_temp.notif_clear_auth();
        raise exception
          'FAIL: anon SELECT unexpected SQLSTATE %', sqlstate;
      end if;
  end;

  perform pg_temp.notif_assert_privilege_error(
    'anon UPDATE',
    $q$update public.notifications set is_read = true$q$
  );
  perform pg_temp.notif_assert_privilege_error(
    'anon INSERT',
    $q$insert into public.notifications (user_id, type, title, body)
       values (
         'a1900000-0000-4000-8000-000000000001',
         'system', 'T', 'B'
       )$q$
  );
  perform pg_temp.notif_assert_privilege_error(
    'anon DELETE',
    $q$delete from public.notifications$q$
  );

  perform pg_temp.notif_clear_auth();
  raise notice 'OK: anon denied SIUD on notifications';
end $$;

-- ---------------------------------------------------------------------------
-- Access: authenticated with no UID
-- ---------------------------------------------------------------------------
do $$
declare
  v_count integer;
  v_n integer;
  v_read boolean;
begin
  perform pg_temp.notif_set_auth_no_uid();

  select count(*) into v_count from public.notifications;
  if v_count <> 0 then
    perform pg_temp.notif_clear_auth();
    raise exception
      'FAIL: authenticated null-uid saw % notification rows', v_count;
  end if;

  update public.notifications
  set is_read = true
  where id = 'b1900000-0000-4000-8000-000000000001';
  get diagnostics v_n = row_count;
  if v_n <> 0 then
    perform pg_temp.notif_clear_auth();
    raise exception 'FAIL: null-uid UPDATE mutated rows';
  end if;

  perform pg_temp.notif_clear_auth();

  select is_read into v_read
  from public.notifications
  where id = 'b1900000-0000-4000-8000-000000000001';
  if v_read is distinct from false then
    raise exception 'FAIL: null-uid UPDATE mutated is_read';
  end if;

  raise notice 'OK: authenticated null-uid isolation';
end $$;

-- ---------------------------------------------------------------------------
-- Access: customer A own select + mark read
-- ---------------------------------------------------------------------------
do $$
declare
  v_count integer;
  v_unread integer;
  v_read boolean;
begin
  perform pg_temp.notif_set_auth('a1900000-0000-4000-8000-000000000001');

  select count(*) into v_count from public.notifications;
  if v_count <> 2 then
    perform pg_temp.notif_clear_auth();
    raise exception 'FAIL: customer A saw % rows (want 2)', v_count;
  end if;

  select count(*) into v_unread
  from public.notifications
  where is_read = false;
  if v_unread <> 1 then
    perform pg_temp.notif_clear_auth();
    raise exception 'FAIL: customer A unread count=% (want 1)', v_unread;
  end if;

  update public.notifications
  set is_read = true
  where id = 'b1900000-0000-4000-8000-000000000001';

  select is_read into v_read
  from public.notifications
  where id = 'b1900000-0000-4000-8000-000000000001';
  if v_read is distinct from true then
    perform pg_temp.notif_clear_auth();
    raise exception 'FAIL: customer A could not mark own row read';
  end if;

  perform pg_temp.notif_clear_auth();
  raise notice 'OK: customer A select + mark read';
end $$;

-- ---------------------------------------------------------------------------
-- Access: customer B isolation + cross-owner update denial
-- ---------------------------------------------------------------------------
do $$
declare
  v_count integer;
  v_n integer;
  v_read boolean;
  v_id uuid;
begin
  perform pg_temp.notif_set_auth('a1900000-0000-4000-8000-000000000002');

  select count(*) into v_count from public.notifications;
  if v_count <> 1 then
    perform pg_temp.notif_clear_auth();
    raise exception 'FAIL: customer B saw % rows (want 1)', v_count;
  end if;

  select count(*) into v_count
  from public.notifications
  where id = 'b1900000-0000-4000-8000-000000000001';
  if v_count <> 0 then
    perform pg_temp.notif_clear_auth();
    raise exception 'FAIL: customer B can see customer A row';
  end if;

  update public.notifications
  set is_read = false
  where id = 'b1900000-0000-4000-8000-000000000001';
  get diagnostics v_n = row_count;
  if v_n <> 0 then
    perform pg_temp.notif_clear_auth();
    raise exception 'FAIL: cross-owner UPDATE mutated rows';
  end if;

  perform pg_temp.notif_clear_auth();

  select is_read into v_read
  from public.notifications
  where id = 'b1900000-0000-4000-8000-000000000001';
  if v_read is distinct from true then
    raise exception 'FAIL: cross-owner UPDATE changed A is_read';
  end if;

  -- B can still toggle own unread row.
  perform pg_temp.notif_set_auth('a1900000-0000-4000-8000-000000000002');
  update public.notifications
  set is_read = true
  where id = 'b1900000-0000-4000-8000-000000000003'
  returning id into v_id;
  if v_id is distinct from 'b1900000-0000-4000-8000-000000000003' then
    perform pg_temp.notif_clear_auth();
    raise exception 'FAIL: customer B could not mark own row read';
  end if;

  perform pg_temp.notif_clear_auth();
  raise notice 'OK: customer B isolation + cross-owner denial';
end $$;

-- ---------------------------------------------------------------------------
-- Access: authenticated cannot mutate immutable columns / insert / delete
-- ---------------------------------------------------------------------------
do $$
declare
  v_title text;
  v_type text;
  v_user uuid;
  v_body text;
  v_payload jsonb;
  v_created timestamptz;
  v_count integer;
begin
  select title, type, user_id, body, payload, created_at
  into v_title, v_type, v_user, v_body, v_payload, v_created
  from public.notifications
  where id = 'b1900000-0000-4000-8000-000000000002';

  perform pg_temp.notif_set_auth('a1900000-0000-4000-8000-000000000001');

  perform pg_temp.notif_assert_privilege_error(
    'customer UPDATE title',
    $q$update public.notifications
       set title = 'Hacked'
       where id = 'b1900000-0000-4000-8000-000000000002'$q$
  );
  perform pg_temp.notif_assert_privilege_error(
    'customer UPDATE body',
    $q$update public.notifications
       set body = 'Hacked'
       where id = 'b1900000-0000-4000-8000-000000000002'$q$
  );
  perform pg_temp.notif_assert_privilege_error(
    'customer UPDATE type',
    $q$update public.notifications
       set type = 'promotion'
       where id = 'b1900000-0000-4000-8000-000000000002'$q$
  );
  perform pg_temp.notif_assert_privilege_error(
    'customer UPDATE user_id',
    $q$update public.notifications
       set user_id = 'a1900000-0000-4000-8000-000000000002'
       where id = 'b1900000-0000-4000-8000-000000000002'$q$
  );
  perform pg_temp.notif_assert_privilege_error(
    'customer UPDATE payload',
    $q$update public.notifications
       set payload = '{"x":1}'::jsonb
       where id = 'b1900000-0000-4000-8000-000000000002'$q$
  );
  perform pg_temp.notif_assert_privilege_error(
    'customer UPDATE created_at',
    $q$update public.notifications
       set created_at = timezone('utc', now()) - interval '1 day'
       where id = 'b1900000-0000-4000-8000-000000000002'$q$
  );
  perform pg_temp.notif_assert_privilege_error(
    'customer INSERT',
    $q$insert into public.notifications (user_id, type, title, body)
       values (
         'a1900000-0000-4000-8000-000000000001',
         'system', 'Self', 'Nope'
       )$q$
  );
  perform pg_temp.notif_assert_privilege_error(
    'customer DELETE',
    $q$delete from public.notifications
       where id = 'b1900000-0000-4000-8000-000000000002'$q$
  );

  perform pg_temp.notif_clear_auth();

  select count(*) into v_count
  from public.notifications
  where id = 'b1900000-0000-4000-8000-000000000002'
    and title is not distinct from v_title
    and type is not distinct from v_type
    and user_id is not distinct from v_user
    and body is not distinct from v_body
    and payload is not distinct from v_payload
    and created_at is not distinct from v_created;
  if v_count <> 1 then
    raise exception 'FAIL: immutable columns mutated after customer attempts';
  end if;

  raise notice 'OK: customer content/owner insert/delete denied';
end $$;

-- ---------------------------------------------------------------------------
-- Access: service_role trusted insert / read / delete
-- ---------------------------------------------------------------------------
do $$
declare
  v_id uuid := 'b1900000-0000-4000-8000-000000000099';
  v_count integer;
begin
  set local role service_role;

  insert into public.notifications (
    id, user_id, type, title, body
  ) values (
    v_id,
    'a1900000-0000-4000-8000-000000000001',
    'order_update',
    'Service created',
    'Trusted insert'
  );

  select count(*) into v_count
  from public.notifications
  where id = v_id;
  if v_count <> 1 then
    reset role;
    raise exception 'FAIL: service_role cannot read inserted row';
  end if;

  delete from public.notifications where id = v_id;
  get diagnostics v_count = row_count;
  if v_count <> 1 then
    reset role;
    raise exception 'FAIL: service_role DELETE affected % rows', v_count;
  end if;

  reset role;
  raise notice 'OK: service_role insert/read/delete';
end $$;

rollback;

\echo '== done =='
