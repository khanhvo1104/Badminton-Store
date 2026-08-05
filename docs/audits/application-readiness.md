# Application readiness audit — Badminton Store

| Field | Value |
|-------|--------|
| Audit date | 2026-08-05 |
| Task | TASK-006 (executable RLS / Storage / RPC / privilege suite; prior TASK-008 grants / TASK-007 trigger EXECUTE / TASK-005 Flutter checkout / TASK-004 backend) |
| Scope | Convert suite 01 to executable regressions + docs; no migrations / Flutter |
| Method | Local `db reset` / SQL regressions / Flutter analyze+test; no remote Supabase mutations |
| Allowed change (TASK-006) | `01_rls_checklist.sql`, optional `01_rls_checklist.sh`, `supabase/README.md`, this audit |

## Verdict

**Commerce MVP path is implementable end-to-end for authenticated COD.** Auth, catalog browse, product detail, search, favorites, cart, addresses, order history, and Flutter checkout UI are wired to Supabase adapters / the trusted `checkout_cod` RPC. Table RLS is enabled; TASK-008 makes Data API grants explicit for CLI 2.111+; TASK-006 makes RLS/Storage/RPC/privilege regressions executable in suite `01`; TASK-009 links Profile to orders, addresses, and settings/logout. Remaining blockers are mostly P1/P2 (stale ops docs outside checkout notes, bootstrap config UX). Full local DB coverage is suites `00`–`05` plus checkout concurrency.

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
| Storage buckets | N/A | Storage provider unwired | Buckets + policies in migration | Suite `01` Storage SIUD | Public read catalog; staff write; avatar ownership |
| RLS verification | N/A | N/A | Policies in `...00008_rls_policies.sql` | Executable suite `01` (+ `05`) | Grants asserted separately from RLS |

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

### P1-2. RLS / storage / privilege scenarios lack executable tests — **RESOLVED (TASK-006)**

- **Resolved in TASK-006:** `supabase/tests/database/01_rls_checklist.sql` (+ `01_rls_checklist.sh`) replaces the comment checklist with transaction-rolled-back assertions: RLS enabled on all 14 app tables; `security_invoker` on catalog/availability views; grant matrix vs RLS behavioral checks; anon catalog boundary; customer A/B isolation; privilege-escalation / forged JWT denial; staff/admin matrix (`is_admin()` distinction only); Storage SELECT/INSERT/UPDATE/DELETE; RPC EXECUTE contracts. Does not change migrations/policies.
- **Resolved in TASK-007 (trigger-helper EXECUTE):** migration `*_lock_down_trigger_function_execute.sql` + `04_trigger_function_execute.sql` prove `PUBLIC`/`anon`/`authenticated` cannot `EXECUTE` `prevent_profile_privilege_escalation`, `assign_order_number`, `record_order_status_change`, and audited `validate_product_image_variant`; `service_role` retains EXECUTE; profile escalation trigger and order number/history triggers still fire. Direct client calls fail with SQLSTATE `42501`.
- **Resolved in TASK-008 (explicit Data API grants):** migration `*_explicit_data_api_grants.sql` enumerates least-privilege table/view/function grants for `anon` / `authenticated` / `service_role` under CLI 2.111+ defaults (no blanket `GRANT ON ALL` / `ALTER DEFAULT PRIVILEGES`). Suite `05_explicit_data_api_grants.sql` asserts grant-layer privileges independently of RLS, then role-switches for representative anon/customer/staff flows. `product_variants.cost_price` table-wide SELECT remains denied; `product_catalog.has_stock` uses `get_variant_availability` so anon needs no raw inventory SELECT.
- **Related suites (not replaced):** `02` cost-price details (TASK-002); `03` + concurrency checkout (TASK-004).
- **Impact:** Authorization regressions across grants, RLS, Storage, and RPC are locally executable after `db reset`.
- **Recommendation:** Keep suite `01` green on fresh resets; any real policy defect found later needs a separately approved migration task.

### P1-3. Primary docs still claim most shop adapters are unimplemented (checkout notes updated)

- **Verified stale claims vs code (remaining):**
  - `docs/architecture.md` — “Shop providers currently throw `UnimplementedError`”; “No `supabase_flutter` network calls are made yet”
  - `docs/coding_guidelines.md` — “Unwired shop repositories may throw `UnimplementedError` until adapters exist”
  - `README.md` — still framed as Dio/fake API starter; demo credentials narrative; incomplete feature list
  - `supabase/README.md` — “Wire Flutter repositories…” still listed as next step
- **Updated in TASK-005:** `docs/backend/flutter_integration_notes.md` no longer claims repositories/PostgREST adapters are unimplemented; it documents the checkout `checkout_cod` RPC payload, note normalization, estimate-only totals, sanitized errors, and success navigation.
- **Verified current wiring:** feature `di/*_providers.dart` files register `Supabase*Repository` / Supabase data sources for auth, home, catalog, product, search, favorites, cart, checkout, addresses, orders, profile; `pubspec.yaml` depends on `supabase_flutter`.
- **Impact:** Agents/humans following remaining stale docs (architecture, coding guidelines, READMEs) may still mis-plan non-checkout work and re-implement existing adapters.
- **Recommendation:** Refresh architecture/coding-guidelines/READMEs to match migrations + DI; keep ADRs for decisions, not outdated status. Checkout Flutter notes are current.

### P1-4. Account routes registered but not linked from shell UI (including logout) — **RESOLVED (TASK-009)**

- **Verified paths:** routes in `lib/app/router/app_router.dart` / `app_routes.dart` for `/settings`, `/orders`, `/addresses`, `/notifications`; logout only in `lib/features/settings/presentation/views/settings_page.dart`.
- **Resolved in TASK-009:** authenticated Profile loaded state pushes `AppRoutes.orders`, `AppRoutes.addresses`, and `AppRoutes.settings` via `context.push` (shell Profile state preserved on back). Settings remains the owner of logout. Notifications stay intentionally unlinked until a backend/repository exists.
- **Impact (historical):** Authenticated users previously could not reach settings/logout, orders, or addresses through normal navigation (deep link only).
- **Recommendation (historical):** Add Profile (or AppBar) entry points; keep notifications as placeholder until backend exists.

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

### P2-3. Limited Flutter tests for remaining Supabase-backed shop repositories / route guards

- **Verified test tree:** `test/features/{authentication,home,profile,settings,checkout,product}/` + `test/core/`.
- **Checkout (TASK-005):** `test/features/checkout/` — `supabase_checkout_repository_test.dart`, `checkout_view_model_test.dart`, `checkout_page_test.dart` — covers RPC payload (exactly address ID + note), sanitized failures, load/address selection/duplicate-submit/success, provider invalidation after success, and widget UI states (empty cart/address, estimate/COD/backend-authority labels, submit progress, durable success + navigation).
- **Still missing:** `test/features/{catalog,cart,orders,favorites,search,addresses,notifications}/` repository/widget suites; broader route-guard widget coverage beyond auth/checkout.
- **Impact:** Checkout regressions are covered in CI; mapping/error-mapping gaps remain for other shop features and account nav entry points.
- **Recommendation:** Add focused repository unit tests with mocked `SupabaseClient` for remaining shop features, plus widget tests for missing nav targets once shell links exist.

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
2. **Authorization is server-side** via `public.profiles.role` helpers (`is_staff_or_admin` / `is_admin`) and `prevent_profile_privilege_escalation` in `supabase/migrations/20260728100002_profiles_and_addresses.sql` — not user-editable JWT metadata. TASK-007 revokes client `EXECUTE` on that helper (and other internal trigger helpers); trusted contract is `service_role` only.
3. **Checkout must not trust client totals** — `public.checkout_cod` recomputes totals server-side (`docs/backend/checkout_security.md`). RLS still blocks customer order/inventory writes; Flutter checkout calls the RPC with address ID + optional note only.
4. **Inventory raw table is staff-only**; public stock via `get_variant_availability` (`...00010_catalog_views_and_rpc.sql`).
5. **Storage:** public read on catalog buckets; staff write; `user-avatars` owner path policies (`...00009_storage_buckets_and_policies.sql`) — executable SIUD coverage in suite `01` (TASK-006).
6. **P0-1** is resolved: public roles cannot SELECT `product_variants.cost_price`; trusted backend/`service_role` access remains.

---

## Test / verification gaps (summary)

| Layer | What exists | Gap |
|-------|-------------|-----|
| Flutter unit/widget | Auth, home, profile, settings, product variant select, core Result/validators/glass, checkout repo/VM/widget | Broader shop repositories (catalog/cart/orders/…), router entry points outside checkout |
| DB constraints | `00_constraints.sql` executable smoke | Broader invariant coverage optional |
| DB RLS / grants | Executable `01` (TASK-006 RLS/Storage/RPC) + `02` cost_price + `03` checkout + `04` trigger EXECUTE + `05` Data API grants | Keep suites green on policy changes |
| Manual / remote | Not run in this audit | No `supabase` remote commands by task rule |

---

## Ordered follow-up tasks

Small, dependency-ordered backlog (each should be its own implementation task):

1. ~~**Hide `cost_price` from public API**~~ — **done in TASK-002** (`20260804145709_protect_product_variant_cost_price.sql`, `02_product_variant_cost_price.sql`, explicit Flutter variant select).
2. ~~**Executable RLS/storage/RPC/privilege test suite**~~ — **done in TASK-006** (`01_rls_checklist.sql` / `01_rls_checklist.sh`); trigger-helper EXECUTE in TASK-007; Data API grants + representative RLS in TASK-008.
3. ~~**Trusted checkout backend**~~ — **done in TASK-004** (`20260804153740_trusted_cod_checkout.sql`, `03_trusted_cod_checkout.sql`, `docs/backend/checkout_security.md`).
4. ~~**Wire checkout UI to trusted API**~~ — **done in TASK-005** (`checkout_cod` Flutter repository/ViewModel/UI; estimate-only totals; sanitized errors; success → `/orders` or catalog).
5. ~~**Profile navigation hub**~~ — **done in TASK-009** (Profile pushes orders, addresses, settings/logout; notifications remain unlinked).
6. **Bootstrap configuration failure UX** — clear error when Supabase env missing instead of composition-root `StateError` (`P1-5`).
7. **Flutter repository tests** for catalog/search/favorites/cart/addresses/orders (`P2-3`; checkout covered in TASK-005; product variant select covered earlier).
8. **Notifications** — only after schema/RLS designed; then repository + UI (`P2-1`).
9. **Documentation cleanup** — `README.md`, `docs/architecture.md`, `docs/coding_guidelines.md`, remaining stale claims in ops docs (`P1-3`, `P2-4`, `P2-6`). Checkout Flutter notes (`docs/backend/flutter_integration_notes.md`) updated in TASK-005.
10. **Optional facade cleanup** — implement or remove `SupabaseDatabase` / `SupabaseStorage` providers (`P2-2`).

Any future schema change must use a **new** Supabase CLI migration and include database/RLS tests. Do not edit deployed migrations.

---

## Checks run

### TASK-009 (this task)

| Check | Result |
|-------|--------|
| `dart format` (changed Dart files) | Passed — `profile_page.dart`, `profile_page_test.dart` |
| `flutter analyze` | Passed — no issues |
| `flutter test test/features/profile` | Passed — ViewModel, use-case, and page widget tests |
| `flutter test` | Passed — all tests |
| `python3 scripts/automation.py policy-check` | Passed |

No schema, migration, RLS, auth, or router architecture changes.

### Historical — TASK-006 (executable RLS / Storage / RPC / privilege suite)

| Check | Result |
|-------|--------|
| `supabase --version` | Passed — `2.111.0` |
| `supabase db reset` (local disposable) | Passed — applied through `20260804170907_explicit_data_api_grants.sql` + seed |
| `00_constraints.sql` | Passed (via `docker exec … psql -v ON_ERROR_STOP=1`) |
| `bash supabase/tests/database/01_rls_checklist.sh` | Passed — grants vs RLS, anon/customer/staff/admin, Storage SIUD, RPC contracts; fixtures rolled back |
| `02_product_variant_cost_price.sql` | Passed |
| `03_trusted_cod_checkout.sql` | Passed |
| `03_trusted_cod_checkout_concurrency.sh` | Passed — concurrent `cart_items` INSERT rejected after checkout; no phantom line |
| `supabase db lint` (local) | Passed — no schema errors |
| `flutter analyze` | Passed — no issues |
| `flutter test` | Passed — all tests |
| `python3 scripts/automation.py policy-check` | Passed |

No remote Supabase migration or link commands are run for TASK-006. No schema/policy changes.

### Historical — TASK-008 (explicit Data API grants)

| Check | Result |
|-------|--------|
| `supabase --version` | Passed — `2.111.0` |
| `supabase stop --no-backup` / `supabase start` | Passed — local disposable stack |
| `supabase db reset` (local disposable) | Passed — applied through `20260804170907_explicit_data_api_grants.sql` + seed |
| `00_constraints.sql` | Passed (via `docker exec … psql -v ON_ERROR_STOP=1`; host `psql` unavailable) |
| `02_product_variant_cost_price.sql` | Passed |
| `03_trusted_cod_checkout.sql` | Passed |
| `04_trigger_function_execute.sql` | Passed |
| `05_explicit_data_api_grants.sql` | Passed — grant-layer matrix, anon catalog RLS, customer CRUD/cross-user, trusted-order boundary, staff/admin + forged JWT denial |
| `03_trusted_cod_checkout_concurrency.sh` | Passed — concurrent `cart_items` INSERT rejected after checkout; no phantom line |
| `supabase db lint` (local) | Passed — no schema errors |
| `flutter analyze` | Passed — no issues |
| `flutter test` | Passed — all tests |
| `python3 scripts/automation.py policy-check` | Passed |

No remote Supabase migration or link commands are run for TASK-008. Remote apply is post-approval/merge only.

### Historical — TASK-007 (trigger-helper EXECUTE)

| Check | Result |
|-------|--------|
| `supabase --version` | Passed — `2.26.9` |
| `supabase db reset` (local disposable) | Passed — applied through `20260804165639_lock_down_trigger_function_execute.sql` + seed |
| `00_constraints.sql` | Passed (via `docker exec … psql -v ON_ERROR_STOP=1`; host `psql` unavailable) |
| `02_product_variant_cost_price.sql` | Passed |
| `03_trusted_cod_checkout.sql` | Passed |
| `04_trigger_function_execute.sql` | Passed — privilege denials (`42501`), profile escalation still blocked, order number/history triggers still fire |
| `03_trusted_cod_checkout_concurrency.sh` | Passed — concurrent `cart_items` INSERT rejected after checkout; no phantom line |
| `supabase db lint` (local) | Passed — no schema errors |
| `flutter analyze` | Passed — no issues |
| `flutter test` | Passed — all tests |
| `python3 scripts/automation.py policy-check` | Passed |

### Historical — TASK-005 (Flutter checkout wiring; not re-characterized here)

| Check | Result |
|-------|--------|
| `dart format --output=none --set-exit-if-changed .` | Passed |
| `flutter analyze` | Passed — no issues |
| `flutter test` | Passed — all tests |
| `python3 scripts/automation.py policy-check` | Passed |

### Historical — TASK-004 (trusted checkout backend)

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

## Remaining work (out of scope for TASK-006)

- ~~Shell navigation hub for settings/orders/addresses (`P1-4`)~~ — **done in TASK-009**
- Refreshing general documentation beyond checkout Flutter notes + this audit's TASK-006 sections
- Remote apply of prior migrations remains post-approval/merge only (this task changes no migrations)
