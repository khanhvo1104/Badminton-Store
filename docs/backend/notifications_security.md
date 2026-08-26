# Notifications security

Private in-app notifications live in `public.notifications`. This document is
the backend contract for Flutter owner read/mark-read and for trusted writers
(service_role or SECURITY DEFINER paths). Flutter consumers are wired
(TASK-019–022); in-repo trusted producers are the readiness follow-up
(TASK-047).

## Ownership and roles

| Actor | PostgreSQL role | Allowed operations |
| --- | --- | --- |
| Signed-in customer | `authenticated` | `SELECT` own rows; `UPDATE` **`is_read` only** |
| Anonymous visitor | `anon` | None |
| Trusted backend / ops | `service_role` | Full table access (create content, read, delete) |

Authorization is always `auth.uid()` against `notifications.user_id`. Do not
derive access from JWT `app_metadata` / `user_metadata` or any other
user-editable claim.

`ON DELETE CASCADE` on `user_id → profiles(id)` is intentional: notifications
are private owner-bound data and must not outlive the profile.

## Column / type mapping (Flutter)

| Column | Postgres | Flutter |
| --- | --- | --- |
| `id` | `uuid` PK | `AppNotification.id` |
| `user_id` | `uuid` FK | `AppNotification.userId` |
| `type` | constrained `text` | `NotificationType` |
| `title` | non-blank `text` | `AppNotification.title` |
| `body` | non-blank `text` | `AppNotification.body` |
| `payload` | object-only `jsonb`, default `{}` | `AppNotification.payload` |
| `is_read` | `boolean`, default `false` | `AppNotification.isRead` |
| `created_at` | `timestamptz` | `AppNotification.createdAt` |

`type` values match Flutter `NotificationType`:

| Flutter enum | Stored value |
| --- | --- |
| `orderUpdate` | `order_update` |
| `promotion` | `promotion` |
| `system` | `system` |
| `stockAlert` | `stock_alert` |

`payload` must be a JSON **object**. Never store secrets, tokens, session
material, or privileged credentials in `payload`.

## Immutability split: grants vs RLS

- **Grants** decide whether a role may attempt an operation. Authenticated
  customers have table `SELECT` and column-level `UPDATE (is_read)` only — not
  table-wide `UPDATE`, and not `INSERT` / `DELETE`.
- **RLS** decides which rows succeed. Both `SELECT` and `UPDATE` policies require
  `auth.uid() is not null` and `user_id = auth.uid()` (`USING` and `WITH CHECK`
  on update).

Content columns (`type`, `title`, `body`, `payload`, `user_id`, `created_at`,
`id`) are immutable to customers at the grant layer. Server / `service_role`
processes create notification content; Flutter may only list, count, and mark
read for the signed-in owner.

## Client query patterns

Newest-first stable pagination (uses
`notifications_user_created_id_idx`):

```sql
select *
from public.notifications
where user_id = auth.uid()
order by created_at desc, id desc
limit :limit
-- optional keyset: and (created_at, id) < (:cursor_created_at, :cursor_id)
;
```

Unread filter / count (uses partial `notifications_user_unread_idx`):

```sql
select count(*) from public.notifications
where user_id = auth.uid() and is_read = false;

update public.notifications
set is_read = true
where id = :id;  -- RLS + column grant enforce owner + is_read-only
```

## Flutter configuration

Use only the Supabase **publishable** key (or legacy **anon** key for
compatibility). Never embed a `service_role` key in the Flutter app, fixtures,
logs, or client examples.

## Out of scope (this backend)

Realtime publication, push / email / SMS delivery, Edge Functions, cron,
broadcast, device tokens, notification preferences, customer `INSERT`/`DELETE`,
and staff compose UI are intentionally not part of the original schema task.

**Current producer gap:** ~~no in-repo migration path inserts notification rows
from `checkout_cod` or `transition_cms_order_status`.~~ **Resolved (TASK-047):**
trusted writers insert exactly one owner-scoped `order_update` row per successful
checkout or status transition inside the same transaction (fail-closed). Push,
Realtime, and other delivery channels remain out of scope.

## Trusted producers (TASK-047)

| Writer | When | Owner | Payload keys |
| --- | --- | --- | --- |
| `public.checkout_cod` | New order successfully created (not idempotent retry) | `orders.user_id` | `order_id`, `order_number`, `event`=`order_placed`, `status`=`pending` |
| `public.transition_cms_order_status` | Successful actual status change only | `orders.user_id` | `order_id`, `order_number`, `event`=`status_changed`, `status`, `from_status`, `to_status` |

Contract:

- `type` is always `order_update`; `title` and `body` are non-blank safe copy (order number + status only).
- `payload` is object-only JSON with string values for the keys above. No address, phone, email, notes, staff identity, tokens, secrets, raw errors, or privileged fields.
- Inserts run inside the writer transaction. Constraint or privilege failure on `public.notifications` rolls back the order write (no silent drop).
- Customers still have no `INSERT`/`DELETE` on `public.notifications`; only these SECURITY DEFINER writers (and `service_role`) create rows.
