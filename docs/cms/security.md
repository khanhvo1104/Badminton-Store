# CMS security and authorization

## Trust model

The CMS is an administrative user interface, not a trusted security boundary.
Requests can be forged outside the UI. Authorization therefore remains in
Postgres RLS, Storage policies, grants, constraints, and narrowly scoped trusted
functions.

## Roles

| Role | CMS access | Intended capability |
| --- | --- | --- |
| `customer` | Denied | Storefront only |
| `staff` | Allowed | Catalog and inventory operations granted by policy |
| `admin` | Allowed | Staff capability plus explicitly admin-only operations |

Role decisions use the trusted `profiles.role` contract and existing database
helpers. User-editable metadata must never grant authorization. Deactivated
profiles must be denied even when an old access token remains valid.

For the CMS SSR app specifically:

- Identity verification for protected requests uses
  `supabase.auth.getClaims()`.
- Proxy refreshes sessions optimistically, but every protected page, Server
  Action, and Route Handler must still enforce authorization independently.
- Authorization reads only `id, full_name, role, is_active` from the caller's
  own `public.profiles` row and allows only active `staff` or active `admin`
  profiles.
- Customer, inactive, missing, malformed, unsupported-role, and query-failure
  cases must all collapse to the same sanitized unauthorized experience.

## Required checks

Protected routes, Server Actions, and Route Handlers must independently:

1. validate the Supabase identity from the server-side session;
2. load the trusted active profile;
3. require the appropriate staff/admin capability;
4. execute data access with the user-scoped session wherever possible;
5. return sanitized errors without SQL, policy, token, or infrastructure data.

A layout redirect alone is insufficient because Next.js has multiple request
entry points. Database enforcement is mandatory even when server checks exist.

## Key handling

- `NEXT_PUBLIC_SUPABASE_URL` and
  `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` may be public.
- Secret/service-role keys, database URLs, passwords, tokens, and private keys
  must never use a `NEXT_PUBLIC_` prefix.
- `.env*` runtime files remain ignored; only placeholders belong in examples.
- Logs, tests, screenshots, fixtures, PR descriptions, and automation artifacts
  must not contain credentials or session cookies.
- A service-role client must not be created as part of the CMS scaffold.
- The CMS must not introduce shared caching or ISR for authenticated pages or
  responses that can refresh/set auth cookies.

## First admin prerequisite

Before TASK-041, the first active `admin` had to be created or promoted manually
by a trusted operator outside the CMS. The admin-only `/dashboard/staff` area
now supports invitations and trusted role/activation changes, but at least one
active admin must still exist to use it.

## Staff management (TASK-041)

Admin-only staff operations use trusted database RPCs plus an Edge Function
invitation boundary:

- `public.list_cms_staff(...)` — SECURITY DEFINER, `is_admin()` only, bounded
  pagination/search, PII-minimized fields (`profile_id`, `full_name`, `email`,
  `role`, `is_active`, `created_at`). Never returns customer profiles or phone/
  avatar metadata.
- `public.update_cms_staff(p_target_id, p_role, p_is_active)` — SECURITY
  DEFINER, `is_admin()` only, blocks self-deactivation/self-demotion, and
  prevents removing the last active admin under concurrency via advisory lock +
  `FOR UPDATE` counting. Writes immutable `staff_management_events`.
- Direct authenticated `UPDATE` on `profiles.role` / `profiles.is_active` is
  blocked by `profiles_enforce_staff_management_boundary` unless a trusted RPC
  sets `app.trusted_staff_management=1`. PostgREST service-role JWTs keep
  `session_user = authenticator`, so invitation finalization must call
  `finalize_cms_staff_invitation` (EXECUTE granted to `service_role` only).
- `profiles_admin_update` replaces the prior staff-wide profile update policy;
  cross-profile updates require active admin.
- `invite-cms-staff` Edge Function validates the caller JWT, re-checks active
  admin from `public.profiles`, then calls `auth.admin.inviteUserByEmail` with
  the runtime service-role key only inside the function. After invite, it calls
  `finalize_cms_staff_invitation` through PostgREST; on finalization failure it
  deletes the newly created auth user before returning a sanitized error. The
  CMS Server Action forwards the user access token; no secret keys ship in the
  browser bundle.
  Redirect URLs come from server `CMS_SITE_URL` and must be Auth allow-listed.
  Default SMTP rate limits surface as sanitized, actionable UI errors; tests never
  send real invitations.

## Privileged audit trail (TASK-042)

`public.cms_privileged_audit_events` is the canonical append-only ledger for
privileged CMS mutations. It is fed transactionally from trusted catalog writes,
`inventory_history`, staff-only `order_status_history` rows, product media
mutations, and `staff_management_events`. Customer checkout seed history
(`from_status IS NULL`) is excluded.

- Metadata is allowlisted per entity/action via
  `validate_cms_privileged_audit_metadata`. No secrets, tokens, addresses, phone
  numbers, customer notes, raw payloads, `cost_price`, or unrestricted row JSON.
- Actor identity comes from `auth.uid()` on staff/admin catalog writes or from
  immutable trusted source columns (`inventory_history.actor_id`,
  `order_status_history.changed_by`, `staff_management_events.actor_id`).
- Direct INSERT/UPDATE/DELETE on the ledger are revoked from PUBLIC/anon/
  authenticated. Reads are admin-only via `list_cms_privileged_audit_events`
  (SECURITY DEFINER, empty search_path, EXECUTE granted to authenticated only).
- Immutability is enforced by grants, RLS, an insert boundary trigger, and
  `prevent_cms_privileged_audit_mutation`. Local/test cleanup uses
  `app.cms_audit_test_cleanup=1` under `session_user = postgres` only.
- CMS `/dashboard/audit` re-authorizes active admin, calls the list RPC, and
  fail-closes malformed metadata in the mapper before rendering summaries.

## Password recovery

Forgotten passwords are recovered through the CMS, not by assigning a password
in the dashboard.

- `CMS_SITE_URL` is required server configuration. Production must be an HTTPS
  origin such as `https://cms.example.com`. `localhost` is accepted only when
  `NODE_ENV` is `development` or `test`. Missing or invalid values fail closed
  and never default to `localhost` in production.
- `resetPasswordForEmail` is called with
  `{CMS_SITE_URL origin}/auth/callback?next=/update-password`.
- Add the exact callback path to the Supabase Auth redirect allow-list:
  `https://cms.example.com/auth/callback`.
- Valid emails always receive the same acknowledgement, whether or not the
  account exists. Provider errors are not shown.
- `/auth/callback` exchanges only a PKCE `code`, validates `next` against an
  internal allow-list (`/update-password`), and never reflects an external URL,
  token, or provider error.
- `/update-password` requires a verified recovery session. GoTrue PKCE
  `resetPasswordForEmail` writes JWT `amr` as `{ method: "recovery", timestamp }`
  (`models.Recovery.String()` / jwt-fields). GoTrue `Session.IsRecovery()` also
  treats `otp` and `magiclink`. Sign-out after a password change is required;
  a returned or thrown `signOut` error is a failure and must not report success.
- `/dashboard` authorization rejects recovery sessions even for active staff or
  admin profiles. CMS access requires a later password sign-in.
- Passwords, recovery codes, and provider errors must not be logged or placed
  in URLs.

## Existing controls to preserve

- RLS is enabled for exposed catalog and inventory tables.
- Staff/admin write policies already cover categories, brands, products,
  variants, images, inventory, and catalog Storage buckets.
- `product_catalog` is a `security_invoker` public projection and excludes cost
  price.
- Storage object operations go through the Storage API; the `storage` schema is
  not modified directly.

## Variant cost price contract

`product_variants.cost_price` remains intentionally not selectable by the shared
`authenticated` database role. Granting that column broadly would expose it to
customers who also authenticate with that role.

Staff and admin CMS sessions read costs through the narrowly scoped RPC
`public.get_staff_variant_costs(p_product_id uuid)`:

- Returns only `variant_id` and nullable `cost_price` for the requested product,
  ordered by `sort_order, id`.
- `SECURITY DEFINER` with empty `search_path`, trusted-profile authorization via
  `auth.uid()` + active `profiles.role IN ('staff', 'admin')`, and EXECUTE
  granted only to `authenticated` (revoked from `PUBLIC`, `anon`, and
  `service_role`).
- Customers, inactive staff, missing/unsupported profiles, and forged JWT
  metadata receive the same generic authorization failure.

### How later CMS product management should combine reads

1. Load normal safe variant fields (sku, price, attributes, activity, and so on)
   through the signed-in user-scoped Supabase client under existing RLS and
   column grants — never select `cost_price` directly.
2. Call `get_staff_variant_costs(product_id)` with the same user-scoped session.
3. Merge the two result sets by `variant_id` in application code.

The authenticated session remains subject to the RPC’s trusted-profile check, so
a service-role browser or server client is unnecessary for cost reads. Do not
cache cost responses across users or weaken the column grant matrix.

The CMS product explorer at `/dashboard/products` reads selling prices through
`public.list_cms_products` with the cookie-backed user JWT and never selects
`cost_price` or calls `get_staff_variant_costs`. Inventory summaries are
aggregated in that SECURITY INVOKER function after `authorizeCmsRequest`.

The per-product variant editor at `/dashboard/products/[productId]/variants`
follows the combine-reads contract above. Mutations use
`public.save_cms_product_variant`, a SECURITY INVOKER RPC that:

- calls trusted `public.is_staff_or_admin()` before any write;
- validates product and variant ownership under caller RLS (`product_id` is
  immutable on update);
- accepts numeric prices as `numeric` and returns only `variant_id`;
- writes `cost_price` and `barcode` through an explicit `unchanged|clear|set`
  contract so an edit never reads or silently clears those columns;
- forces the first variant to be default and rejects unsetting the current
  default unless another default is selected in the same call;
- serializes default switches with a per-product transaction advisory lock,
  unsets the prior default, then sets the target.

`barcode` remains absent from the authenticated SELECT grant. The editor
therefore cannot prefill barcode; create may set it, and edit preserves it
unless staff supply a new value or an explicit clear. Do not add a barcode
read RPC unless a later task expands that contract on purpose.

SKU normalization (CMS and RPC): trim, collapse internal whitespace to a
single space, preserve case, require 1..80 characters.

## Inventory and state transitions

The CMS must not treat direct client-side updates as sufficient for stock or
privileged workflow transitions. Inventory adjustments go through
`public.adjust_cms_inventory`, a narrow SECURITY DEFINER RPC with empty
`search_path`, `is_staff_or_admin()` authorization, `auth.uid()` as actor,
inventory row locking, and a same-transaction insert into immutable
`public.inventory_history`. Direct authenticated INSERT/UPDATE/DELETE on
history are closed. `adjust_cms_inventory` returns only `variant_id`; the CMS
Server Action fail-closes empty, multiple, malformed, mismatched, or extra-field
payloads. `public.list_cms_inventory` is SECURITY INVOKER and never
selects `cost_price` or `barcode`. Reserved quantity cannot be edited.

Order status changes go through `public.transition_cms_order_status`, a narrow
SECURITY DEFINER RPC with empty `search_path`, `is_staff_or_admin()` +
`auth.uid()`, order and inventory row locks, an explicit transition graph, and
atomic inventory effects. Authenticated `UPDATE` on `public.orders` is revoked
so direct status writes are impossible over the Data API; reads remain via RLS.
History is written exactly once by `orders_record_status_history`. Payment
status is read-only in the CMS.

## Product media

Product images are staff/admin catalog mutations over existing
`product_images` RLS and the public `product-images` bucket.

- `set_cms_product_image_primary(p_product_id uuid, p_image_id uuid)` is
  SECURITY INVOKER with empty `search_path`, `is_staff_or_admin()`
  authorization, a per-product advisory lock, and a two-step unset-then-set
  so unique indexes are not raced. It returns only `image_id`. SECURITY
  DEFINER is not used because staff already have table UPDATE under RLS.
- `reorder_cms_product_images(p_product_id uuid, p_image_ids uuid[])` is the
  matching bounded reorder RPC (1..20 complete, product-scoped ids) and
  returns only `product_id`.
- `insert_cms_product_image` inserts the row and assigns primary in one
  locked transaction. `update_cms_product_image` moves variant scope and
  maintains old/destination primaries in one locked transaction. Both return
  only `image_id`.
- Upload: validate raster MIME/size, generate `{productId}/{uuid}.ext`,
  `upsert: false`, then call `insert_cms_product_image`. If the RPC fails,
  best-effort delete the newly uploaded object.
- Replace: upload a new unique object, update `storage_path`, then delete the
  old object. On database failure, delete the new object and keep the old
  working image.
- Delete: if the target is primary, promote the next remaining image in the
  same scope first (while both rows still exist). Then remove the database
  row (never leaving a row pointing at a missing object), then best-effort
  delete the Storage object. Cleanup failure is a sanitized warning. Fully
  atomic Storage+Postgres delete is impossible; orphaned objects are the
  retryable failure mode.
- SVG is never accepted or inlined. Previews are public object URLs built
  from stored paths that stay under the product folder.

## Storage rules

- Validate MIME type, extension, size, bucket, and normalized object path.
- Use deterministic resource folders without accepting arbitrary traversal.
- Upload/replace/delete policies must cover the exact Storage operations used.
- Replacement requires the relevant insert, select, and update permissions.
- Deleting a catalog image must coordinate database references and object
  deletion, with retryable cleanup for partial failure.

## Verification matrix

| Actor | Catalog read | Catalog write | Cost price | Inventory write | Asset write |
| --- | --- | --- | --- | --- | --- |
| Anonymous | Public active projection only | Denied | Denied (no RPC EXECUTE; no column SELECT) | Denied | Denied |
| Customer | Public active projection only | Denied | Denied (`get_staff_variant_costs` authz failure; no column SELECT) | Denied | Denied |
| Inactive staff | Denied from CMS operations | Denied | Denied (same authz failure) | Denied | Denied |
| Active staff | Authorized scope | Authorized scope | `get_staff_variant_costs` only | Authorized RPC/policy | Catalog buckets |
| Active admin | Authorized scope | Authorized scope | `get_staff_variant_costs` only | Authorized RPC/policy | Catalog buckets |

Executable tests must cover positive and negative cases. A UI test that hides a
button does not satisfy an RLS or privilege acceptance criterion.
