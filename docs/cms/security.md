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

The CMS does not include self-signup, invitations, or role-editing tools. The
first active `admin` must be created or promoted manually by a trusted operator
outside the CMS before staff can sign in successfully.

## Existing controls to preserve

- RLS is enabled for exposed catalog and inventory tables.
- Staff/admin write policies already cover categories, brands, products,
  variants, images, inventory, and catalog Storage buckets.
- `product_catalog` is a `security_invoker` public projection and excludes cost
  price.
- Storage object operations go through the Storage API; the `storage` schema is
  not modified directly.

## Known prerequisite: variant cost price

`product_variants.cost_price` is intentionally not selectable by the shared
`authenticated` database role. Granting that column broadly would expose it to
customers who also authenticate with that role. Product variant management must
therefore wait for a dedicated staff/admin read contract, such as a narrowly
scoped RPC or protected projection with executable authorization tests.

The solution must not weaken the existing column privilege and must not expose a
generic security-definer endpoint. If privileged code is necessary, it must
check the caller, fix its `search_path`, revoke default `PUBLIC` execution, grant
only intended roles, and receive advisor and regression coverage.

## Inventory and state transitions

The CMS must not treat direct client-side updates as sufficient for stock or
privileged workflow transitions. Inventory adjustments require an atomic
database operation with validation and an auditable reason. Future order status
changes require explicit transition rules enforced server-side.

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
| Anonymous | Public active projection only | Denied | Denied | Denied | Denied |
| Customer | Public active projection only | Denied | Denied | Denied | Denied |
| Inactive staff | Denied from CMS operations | Denied | Denied | Denied | Denied |
| Active staff | Authorized scope | Authorized scope | Dedicated contract | Authorized RPC/policy | Catalog buckets |
| Active admin | Authorized scope | Authorized scope | Dedicated contract | Authorized RPC/policy | Catalog buckets |

Executable tests must cover positive and negative cases. A UI test that hides a
button does not satisfy an RLS or privilege acceptance criterion.
