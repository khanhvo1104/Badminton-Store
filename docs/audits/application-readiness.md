# Application readiness audit — Badminton Store

| Field | Value |
|-------|--------|
| Audit date | 2026-08-04 |
| Task | TASK-005 (Flutter checkout wiring; prior TASK-004 checkout backend) |
| Scope | Flutter checkout UI/repository wired to `checkout_cod`; prior baseline includes TASK-004 backend |
| Method | Implementation + Flutter analyze/test; no remote Supabase mutations |
| Allowed change (TASK-005) | Flutter checkout feature paths, related cart/address/order/router touchpoints, checkout docs/audit notes |

## Verdict

**Commerce MVP path is implementable end-to-end for authenticated COD.** Auth, catalog browse, product detail, search, favorites, cart, addresses, order history, and Flutter checkout UI are wired to Supabase adapters / the trusted `checkout_cod` RPC. Table RLS is enabled in migrations. Remaining blockers are mostly P1/P2 (executable RLS breadth beyond cost_price/checkout, stale ops docs outside checkout notes, missing shell nav to account routes). Database RLS verification is mostly a comment checklist, not executable tests (except the P0-1 cost_price regression and TASK-004 checkout suite).

**Legend:** *Verified* = confirmed in source/migrations. *Inferred* = likely impact from wiring/docs without runtime proof.

---

## Verified subsystem matrix

| Subsystem | UI | Provider / repo wiring | Backend (migrations) | Flutter tests | Notes |
|-----------|----|------------------------|----------------------|---------------|-------|
| Bootstrap / env | N/A | Overrides in `lib/app/bootstrap.dart` | N/A | Partial (test container) | `appEnvironmentProvider` / `sharedPreferencesProvider` require overrides |
| Authentication | Login, splash | Supabase remote DS + local secure storage | Auth users → profiles trigger | Strong (`test/features/authentication/`) | Fake DS used in tests only |
| Home | Shell tab | `SupabaseHomeRemoteDataSource` → featured `product_catalog` | Catalog view | Unit/VM tests with fakes | Not a commerce dashboard |
| Catalog | Shell tab | Supabase category/brand + product list | RLS + `product_catalog` | None for repos | Wired contrary to stale docs |
| Product detail | Push `/product/:id` | `SupabaseProductRepository` | Variants/images + availability RPC | Repository select projection | Explicit safe variant columns (P0-1 resolved) |
| Search | Push `/search` | `SupabaseSearchRepository` | `search_products` RPC | None | Reachable from catalog app bar |
| Favorites | Shell tab | `SupabaseFavoriteRepository` | Own-row RLS | None | |
| Cart | Shell tab | `SupabaseCartRepository` | Own cart RLS | None | Checkout CTA navigates to wired COD checkout |
| Checkout | Push `/checkout` | `checkoutRepositoryProvider` → `checkout_cod` | `checkout_cod` SECURITY DEFINER RPC (TASK-004); no customer order INSERT | Repo/VM/widget tests | **Wired in TASK-005**; display totals informational only |
| Orders | Push `/orders` | `SupabaseOrderRepository` (read) | Own SELECT; staff write | None | Reachable from checkout success; no shell nav link |
| Addresses | Push `/addresses` | `SupabaseAddressRepository` | Own CRUD RLS | None | Reachable from checkout; demo FAB create remains |
| Profile | Shell tab | Supabase profile DS + use case | Profile RLS + privilege trigger | Use case / VM tests | Display-name edit path |
| Settings / logout | Push `/settings` | Appearance prefs | N/A | Appearance widget test | **No in-app nav to settings** |
| Notifications | Push `/notifications` | `UnimplementedError` if provider read | **No notifications table** | None | UI is placeholder only (safe) |
| Design system | Debug `/design-system` | N/A | N/A | Glass widget tests | Gated by `kDebugMode` |
| Supabase core facades | N/A | Auth DS wired; DB/Storage providers throw | Migrations present | None | Repos use `supabaseClientProvider` directly |
| Storage buckets | N/A | Storage provider unwired | Buckets + policies in migration | No executable storage tests | Public read catalog; staff write; avatar ownership |
| RLS verification | N/A | N/A | Policies in `...00008_rls_policies.sql` | Comment checklist only | Constraint smoke SQL is executable |

---

## Incomplete / stub inventory (reachability)

| Site | Behavior | Reachable from UI? | User impact |
|------|----------|-------------------|-------------|
| `lib/features/notifications/presentation/views/notifications_page.dart` | `ShopPlaceholderPage` | Only via deep link (no nav entry found) | Empty placeholder |
| `lib/features/notifications/di/notifications_providers.dart` | `UnimplementedError` | **No** — page does not watch the provider | Crash only if a future caller reads the provider |
| `lib/core/supabase/supabase_providers.dart` (`supabaseDatabaseProvider`, `supabaseStorageProvider`) | `UnimplementedError` | **No** — no feature watches them | Interim repos use `SupabaseClient` directly |
| `lib/core/config/environment_provider.dart` | Must override | Overridden in bootstrap/tests | Expected DI pattern |
| `lib/core/storage/storage_providers.dart` (`sharedPreferencesProvider`) | Must override | Overridden in bootstrap/tests | Expected DI pattern |
| `lib/core/supabase/supabase_session_manager.dart` (`PendingSupabaseSessionManager`) | Placeholder when not initialized | Used when init skipped | Soft-degraded session manager; client provider still hard-fails |

---

## P0 — release-blocking

### P0-1. `cost_price` readable by public API roles on `product_variants` — **RESOLVED**

- **Resolution (TASK-002):**
  - Migration: `supabase/migrations/20260804145709_protect_product_variant_cost_price.sql` — revokes table-wide SELECT from `anon`/`authenticated` and grants only the safe public variant columns (no `cost_price`). Flutter staff/admin JWTs intentionally remain under the same column restriction; `service_role`/direct DB credentials are unchanged.
  - Flutter: `lib/features/product/data/repositories/supabase_product_repository.dart` — `getById` uses an explicit `product_variants` select projection matching the mapper (excludes `cost_price` and `*`).
  - Regression: `supabase/tests/database/02_product_variant_cost_price.sql` — asserts column privileges, role-switched safe reads, `cost_price` denial, and active-row RLS boundary.
  - Flutter coverage: `test/features/product/supabase_product_repository_test.dart` — asserts `supabaseProductVariantSelect` contains every mapper field and excludes `cost_price`/`*`.
- **Prior verified gap (historical):** RLS row SELECT alone could not hide `cost_price`; `product_catalog` already omitted it, but direct `product_variants` SELECT leaked the column.

---

## P1 — core gaps / verification / ops

### P1-1. Checkout UI wired to trusted COD RPC — **RESOLVED (TASK-005)**

- **Backend (TASK-004 — complete):**
  - Migration: `supabase/migrations/20260804153740_trusted_cod_checkout.sql` — `public.checkout_cod(uuid, text) returns uuid` (`SECURITY DEFINER`, `search_path = ''`) plus `cart_items_enforce_active_cart` trigger to reject post-conversion phantom `cart_items` inserts. Reprices from `product_variants.price`, reserves inventory, snapshots order/items/address, converts active cart; COD-only constants (`unpaid`, zero discount/shipping).
  - Grants: `EXECUTE` for `authenticated` + `service_role` only; revoked from `PUBLIC`/`anon`. Still rejects null `auth.uid()`.
  - Regression: `supabase/tests/database/03_trusted_cod_checkout.sql` — authz, ownership, validation rollback, totals/snapshots, reservation, backorder, idempotent retry, converted-cart insert denial; `03_trusted_cod_checkout_concurrency.sh` — two-session phantom insert vs checkout.
  - Docs: `docs/backend/checkout_security.md` describes the RPC contract (not an Edge Function / not a Flutter service-role key).
- **Flutter (TASK-005 — complete):** `SupabaseCheckoutRepository` calls only `checkout_cod` with `p_shipping_address_id` + normalized `p_customer_note`; checkout ViewModel/UI loads cart + owned addresses, blocks double submit, shows estimate-only totals, maps sanitized failures to Vietnamese copy, invalidates cart/orders providers, and keeps a durable success state with navigation to `/orders` or `/catalog`.
- **Impact:** Authenticated customers with a non-empty cart and owned address can place COD orders in-app. Customer RLS still blocks direct order/inventory writes.
- **Recommendation:** Keep client totals display-only; do not broaden table RLS; replace address demo FAB with a real form in a later task.

### P1-2. RLS / storage / privilege scenarios lack executable tests

- **Verified paths:**
  - Executable: `supabase/tests/database/00_constraints.sql` (slug/price/role/order math smoke)
  - Non-executable checklist: `supabase/tests/database/01_rls_checklist.sql` (comments + `select 'See comments...'`)
- **Missing coverage (verified absence):** broad cross-user address/cart/order isolation outside checkout; anon catalog vs draft denial; staff/admin matrix; storage bucket policies; general RPC grants; `prevent_profile_privilege_escalation`. (`cost_price` covered by `02_product_variant_cost_price.sql`; checkout RPC covered by `03_trusted_cod_checkout.sql`.)
- **Impact:** Policies may be correct in SQL but regressions can ship undetected.
- **Recommendation:** Convert the checklist into role-switched executable tests (pgTAP or scripted `set local role` / JWT claims) before further policy edits.

### P1-3. Primary docs claim shop Supabase adapters are still unimplemented

- **Verified stale claims vs code:**
  - `docs/architecture.md` — “Shop providers currently throw `UnimplementedError`”; “No `supabase_flutter` network calls are made yet”
  - `docs/backend/flutter_integration_notes.md` — “Repository implementations and PostgREST data sources remain unimplemented”
  - `docs/coding_guidelines.md` — “Unwired shop repositories may throw `UnimplementedError` until adapters exist”
  - `README.md` — still framed as Dio/fake API starter; demo credentials narrative; incomplete feature list
  - `supabase/README.md` — “Wire Flutter repositories…” still listed as next step
- **Verified current wiring:** feature `di/*_providers.dart` files register `Supabase*Repository` / Supabase data sources for auth, home, catalog, product, search, favorites, cart, addresses, orders, profile; `pubspec.yaml` depends on `supabase_flutter`.
- **Impact:** Agents/humans following docs will mis-plan work and re-implement existing adapters.
- **Recommendation:** Refresh those docs to match migrations + DI; keep ADRs for decisions, not outdated status.

### P1-4. Account routes registered but not linked from shell UI (including logout)

- **Verified paths:** routes in `lib/app/router/app_router.dart` / `app_routes.dart` for `/settings`, `/orders`, `/addresses`, `/notifications`; logout only in `lib/features/settings/presentation/views/settings_page.dart`; no `context.push(AppRoutes.settings|orders|addresses|notifications)` elsewhere under `lib/` (Catalog→Search and Cart→Checkout are the only shop push links found).
- **Impact:** Authenticated users cannot reach settings/logout, orders, addresses, or notifications through normal navigation (deep link only).
- **Recommendation:** Add Profile (or AppBar) entry points; keep notifications as placeholder until backend exists.

### P1-5. Missing Supabase config soft-skips init but hard-fails client providers

- **Verified paths:** `lib/core/supabase/supabase_initializer.dart` (skips when unconfigured), `lib/core/supabase/supabase_providers.dart` (`supabaseClientProvider` throws `StateError` if not initialized), auth/home/shop providers all `ref.watch(supabaseClientProvider)`.
- **Impact (inferred):** Without env keys, splash session restore can fail hard / leave loading state instead of a clear configuration error.
- **Recommendation:** Fail closed with an explicit bootstrap error UI, or gate repository providers on `isInitialized` with `Result` failures — do not throw from composition roots during session restore.

---

## P2 — secondary / maintainability / coverage

### P2-1. Notifications feature is domain + placeholder only

- **Paths:** `lib/features/notifications/**`, `lib/shared/widgets/shop_placeholder_page.dart`; no `notifications` table under `supabase/migrations/`.
- **Impact:** Secondary feature; provider throws if wired prematurely.
- **Recommendation:** After commerce MVP, add schema + RLS + repository, then replace placeholder.

### P2-2. Generic `SupabaseDatabase` / `SupabaseStorage` providers unwired

- **Path:** `lib/core/supabase/supabase_providers.dart`
- **Impact:** Dead DI surface; repos bypass facades via `SupabaseClient`.
- **Recommendation:** Implement facades and migrate repositories, or delete unused providers to reduce trap hazards.

### P2-3. No Flutter tests for Supabase-backed shop repositories / route guards / locked checkout

- **Verified test tree:** `test/features/{authentication,home,profile,settings}/` + `test/core/`; **no** `test/features/{catalog,product,cart,checkout,orders,favorites,search,addresses,notifications}/`.
- **Impact:** Regressions in mapping, error mapping, and incomplete-feature behavior go unnoticed in CI.
- **Recommendation:** Add focused repository unit tests with mocked `SupabaseClient`, plus widget tests for checkout lock and missing nav targets once links exist.

### P2-4. Money typing guidance vs entities disagree

- **Paths:** `docs/coding_guidelines.md` (int minor units) vs domain entities using `double` (e.g. `lib/features/product/domain/entities/product_variant.dart`, cart/order amounts) and `docs/backend/flutter_integration_notes.md` (double for VND whole units).
- **Impact:** Inconsistent contributor guidance; float risk if used for accounting (server remains source of truth for checkout).
- **Recommendation:** Align guidelines with chosen domain representation; keep server-side numeric as authority.

### P2-5. Addresses UI is a demo FAB, not a full form flow

- **Path:** `lib/features/addresses/presentation/views/addresses_page.dart` (hard-coded sample `Address` on create).
- **Impact:** Functional smoke path only; poor real-user UX.
- **Recommendation:** Replace with validated address form after nav entry exists.

### P2-6. Stale inline comments on wired providers

- **Paths:** e.g. `lib/features/catalog/di/catalog_providers.dart` (“later milestone”), `lib/features/orders/domain/repositories/order_repository.dart` / product repository interface comments claiming later milestone despite Supabase impls.
- **Impact:** Local confusion during reviews.
- **Recommendation:** Clean comments when touching those files.

### P2-7. Home still presents a generic dashboard, not storefront merchandising

- **Paths:** `lib/features/home/presentation/views/home_page.dart`, `supabase_home_remote_data_source.dart` (featured products as dashboard cards).
- **Impact:** Usable but not storefront-polished.
- **Recommendation:** Deferred UX work after commerce completeness.

---

## Security boundaries (explicit)

1. **Flutter may only use publishable/anon keys** — see `lib/core/supabase/supabase_config.dart`, `AGENTS.md`. Never embed service-role keys.
2. **Authorization is server-side** via `public.profiles.role` helpers (`is_staff_or_admin` / `is_admin`) and `prevent_profile_privilege_escalation` in `supabase/migrations/20260728100002_profiles_and_addresses.sql` — not user-editable JWT metadata.
3. **Checkout must not trust client totals** — `public.checkout_cod` recomputes totals server-side (`docs/backend/checkout_security.md`). RLS still blocks customer order/inventory writes; Flutter checkout calls the RPC with address ID + optional note only.
4. **Inventory raw table is staff-only**; public stock via `get_variant_availability` (`...00010_catalog_views_and_rpc.sql`).
5. **Storage:** public read on catalog buckets; staff write; `user-avatars` owner path policies (`...00009_storage_buckets_and_policies.sql`) — not executable-tested yet (P1-2).
6. **P0-1** is resolved: public roles cannot SELECT `product_variants.cost_price`; trusted backend/`service_role` access remains.

---

## Test / verification gaps (summary)

| Layer | What exists | Gap |
|-------|-------------|-----|
| Flutter unit/widget | Auth, home, profile, settings, core Result/validators/glass, checkout repo/VM/widget | Broader shop repositories, router entry points outside checkout |
| DB constraints | `00_constraints.sql` executable smoke | Broader invariant coverage optional |
| DB RLS | Comment plan in `01_rls_checklist.sql` + `02_product_variant_cost_price.sql` + `03_trusted_cod_checkout.sql` | Executable anon/customer/staff/storage/escalation tests beyond cost_price/checkout |
| Manual / remote | Not run in this audit | No `supabase` remote commands by task rule |

---

## Ordered follow-up tasks

Small, dependency-ordered backlog (each should be its own implementation task):

1. ~~**Hide `cost_price` from public API**~~ — **done in TASK-002** (`20260804145709_protect_product_variant_cost_price.sql`, `02_product_variant_cost_price.sql`, explicit Flutter variant select).
2. **Executable RLS/storage/RPC/privilege test suite** — replace/extend `01_rls_checklist.sql` with runnable tests (`P1-2`); do this before further policy edits.
3. ~~**Trusted checkout backend**~~ — **done in TASK-004** (`20260804153740_trusted_cod_checkout.sql`, `03_trusted_cod_checkout.sql`, `docs/backend/checkout_security.md`).
4. ~~**Wire checkout UI to trusted API**~~ — **done in TASK-005** (`checkout_cod` Flutter repository/ViewModel/UI; estimate-only totals; sanitized errors; success → `/orders` or catalog).
5. **Profile navigation hub** — links to settings (logout), orders, addresses; optional notifications placeholder (`P1-4`).
6. **Bootstrap configuration failure UX** — clear error when Supabase env missing instead of composition-root `StateError` (`P1-5`).
7. **Flutter repository tests** for catalog/product/search/favorites/cart/addresses/orders (`P2-3`; checkout covered in TASK-005).
8. **Notifications** — only after schema/RLS designed; then repository + UI (`P2-1`).
9. **Documentation cleanup** — `README.md`, `docs/architecture.md`, `docs/coding_guidelines.md`, remaining stale claims in ops docs (`P1-3`, `P2-4`, `P2-6`). Checkout Flutter notes updated in TASK-005.
10. **Optional facade cleanup** — implement or remove `SupabaseDatabase` / `SupabaseStorage` providers (`P2-2`).

Any future schema change must use a **new** Supabase CLI migration and include database/RLS tests. Do not edit deployed migrations.

---

## Checks run

### TASK-005 (this task)

| Check | Result |
|-------|--------|
| `dart format --output=none --set-exit-if-changed .` | Passed |
| `flutter analyze` | Passed — no issues |
| `flutter test` | Passed — all tests |
| `python3 scripts/automation.py policy-check` | Passed |

No remote Supabase migration or link commands were run for TASK-005. Database reset, RLS/SQL regression, concurrency, and `supabase db lint` were **not** re-run (no schema/migration changes in this task).

### Historical — TASK-004 (trusted checkout backend; not re-run in TASK-005)

| Check | Result |
|-------|--------|
| `supabase db reset` (local disposable) | Passed — applied through `20260804153740_trusted_cod_checkout.sql` + seed |
| `00_constraints.sql` | Passed (duplicate-slug probe uses seeded `vot-cau-long`; non-seeded `rackets` does not collide) |
| `01_rls_checklist.sql` | Passed (comment checklist smoke) |
| `02_product_variant_cost_price.sql` | Passed |
| `03_trusted_cod_checkout.sql` | Passed |
| `03_trusted_cod_checkout_concurrency.sh` | Passed — concurrent `cart_items` INSERT rejected after checkout; no phantom line |
| `supabase db lint` (local) | Passed — no schema errors |

### Historical — TASK-001 baseline

| Check | Result |
|-------|--------|
| `flutter analyze` / `flutter test` | Passed during audit authoring |

---

## Remaining work (out of scope for TASK-005)

- Broader executable RLS/storage suite (`P1-2`)
- Shell navigation hub for settings/orders/addresses (`P1-4`)
- Refreshing general documentation beyond checkout Flutter notes + this audit's checkout sections
- Contacting remote Supabase
