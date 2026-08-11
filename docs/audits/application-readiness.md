# Application readiness audit — Badminton Store

| Field | Value |
|-------|--------|
| Audit date | 2026-08-11 |
| Task | TASK-018 (documentation / money guidance / stale-comment cleanup; prior TASK-011–017 coverage reflected) |
| Scope | Refresh README, architecture, coding guidelines, Supabase README, this audit; comment-only fixes on wired repos |
| Method | Verified against current DI, entities, migrations, and test tree; no remote Supabase mutations |
| Allowed change (TASK-018) | Listed Markdown + comment paths in TASK-018; `.automation/backlog.json` |

## Verdict

**Commerce MVP path is implementable end-to-end for authenticated COD.** Auth, catalog browse, product detail, search, favorites, cart, addresses (validated form), order history, Profile account navigation, configuration-error UX, and Flutter checkout UI are wired to Supabase adapters / the trusted `checkout_cod` RPC. Table RLS is enabled; Data API grants, trigger EXECUTE lockdown, and executable suites `00`–`05` plus checkout concurrency cover the local DB. Flutter repository regressions exist for catalog/search/favorites/cart/addresses/orders (TASK-011–015) plus route-guard/nav tests (TASK-017). Documentation, money guidance, and stale “later milestone” comments on wired repos are aligned in TASK-018.

**Remaining work (P2):** Notifications (placeholder), optional `SupabaseDatabase` / `SupabaseStorage` facade cleanup, Home storefront polish.

**Legend:** *Verified* = confirmed in source/migrations. *Inferred* = likely impact from wiring/docs without runtime proof.

---

## Verified subsystem matrix

| Subsystem | UI | Provider / repo wiring | Backend (migrations) | Flutter tests | Notes |
|-----------|----|------------------------|----------------------|---------------|-------|
| Bootstrap / env | Configuration-error app when unconfigured | Overrides in `lib/app/bootstrap.dart` | N/A | Strong (`test/app/`) | Incomplete config → `ConfigurationErrorApp` (TASK-010) |
| Authentication | Login, splash | Supabase remote DS + local secure storage | Auth users → profiles trigger | Strong (`test/features/authentication/`) | Fake DS used in tests only |
| Home | Shell tab | `SupabaseHomeRemoteDataSource` → featured `product_catalog` | Catalog view | Unit/VM tests with fakes | Not a commerce dashboard |
| Catalog | Shell tab | Supabase category/brand + product list | RLS + `product_catalog` | Repo tests (TASK-011) | Wired |
| Product detail | Push `/product/:id` | `SupabaseProductRepository` | Variants/images + availability RPC | Repository select projection | Explicit safe variant columns (P0-1 resolved) |
| Search | Push `/search` | `SupabaseSearchRepository` | `search_products` RPC | Repo tests (TASK-011) | Reachable from catalog app bar |
| Favorites | Shell tab | `SupabaseFavoriteRepository` | Own-row RLS | Repo tests (TASK-012) | |
| Cart | Shell tab | `SupabaseCartRepository` | Own cart RLS | Repo tests (TASK-013) | Checkout CTA → COD checkout |
| Checkout | Push `/checkout` | `checkoutRepositoryProvider` → `checkout_cod` | `checkout_cod` SECURITY DEFINER RPC; no customer order INSERT | Repo/VM/widget tests | Display totals informational only |
| Orders | Push `/orders` | `SupabaseOrderRepository` (read) | Own SELECT; staff write | Repo tests (TASK-015) | Profile hub + checkout success |
| Addresses | Push `/addresses` | `SupabaseAddressRepository` | Own CRUD RLS | Repo + form/UI tests (TASK-014/016) | Validated create/edit form (TASK-016) |
| Profile | Shell tab | Supabase profile DS + use case | Profile RLS + privilege trigger | Use case / VM / page tests | Links to orders/addresses/settings (TASK-009) |
| Settings / logout | Push `/settings` | Appearance prefs | N/A | Appearance + nav tests | Reachable from Profile |
| Notifications | Push `/notifications` | `UnimplementedError` if provider read | **No notifications table** | None | UI is placeholder only (safe); intentionally unlinked |
| Design system | Debug `/design-system` | N/A | N/A | Glass widget tests | Gated by `kDebugMode` |
| Supabase core facades | N/A | Auth DS wired; DB/Storage providers throw | Migrations present | None | Repos use `supabaseClientProvider` directly |
| Storage buckets | N/A | Storage provider unwired | Buckets + policies in migration | Suite `01` Storage SIUD | Public read catalog; staff write; avatar ownership |
| RLS verification | N/A | N/A | Policies in `...00008_rls_policies.sql` | Executable suite `01` (+ `05`) | Grants asserted separately from RLS |
| Route guards / nav | Shell + push | `auth_redirect_policy.dart` | N/A | TASK-017 regressions | Unauth redirect + authenticated hub links |

---

## Incomplete / stub inventory (reachability)

| Site | Behavior | Reachable from UI? | User impact |
|------|----------|-------------------|-------------|
| `lib/features/notifications/presentation/views/notifications_page.dart` | `ShopPlaceholderPage` | Only via deep link (no nav entry) | Empty placeholder |
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
- **Recommendation:** Keep client totals display-only; do not broaden table RLS.

### P1-2. RLS / storage / privilege scenarios lack executable tests — **RESOLVED (TASK-006)**

- **Resolved in TASK-006:** `supabase/tests/database/01_rls_checklist.sql` (+ `01_rls_checklist.sh`) replaces the comment checklist with transaction-rolled-back assertions: RLS enabled on all 14 app tables; `security_invoker` on catalog/availability views; grant matrix vs RLS behavioral checks; anon catalog boundary; customer A/B isolation; privilege-escalation / forged JWT denial; staff/admin matrix (`is_admin()` distinction only); Storage SELECT/INSERT/UPDATE/DELETE; RPC EXECUTE contracts. Does not change migrations/policies.
- **Resolved in TASK-007 (trigger-helper EXECUTE):** migration `*_lock_down_trigger_function_execute.sql` + `04_trigger_function_execute.sql` prove `PUBLIC`/`anon`/`authenticated` cannot `EXECUTE` `prevent_profile_privilege_escalation`, `assign_order_number`, `record_order_status_change`, and audited `validate_product_image_variant`; `service_role` retains EXECUTE; profile escalation trigger and order number/history triggers still fire. Direct client calls fail with SQLSTATE `42501`.
- **Resolved in TASK-008 (explicit Data API grants):** migration `*_explicit_data_api_grants.sql` enumerates least-privilege table/view/function grants for `anon` / `authenticated` / `service_role` under CLI 2.111+ defaults (no blanket `GRANT ON ALL` / `ALTER DEFAULT PRIVILEGES`). Suite `05_explicit_data_api_grants.sql` asserts grant-layer privileges independently of RLS, then role-switches for representative anon/customer/staff flows. `product_variants.cost_price` table-wide SELECT remains denied; `product_catalog.has_stock` uses `get_variant_availability` so anon needs no raw inventory SELECT.
- **Related suites (not replaced):** `02` cost-price details (TASK-002); `03` + concurrency checkout (TASK-004).
- **Impact:** Authorization regressions across grants, RLS, Storage, and RPC are locally executable after `db reset`.
- **Recommendation:** Keep suite `01` green on fresh resets; any real policy defect found later needs a separately approved migration task.

### P1-3. Primary docs claimed most shop adapters were unimplemented — **RESOLVED (TASK-018)**

- **Resolved in TASK-018:**
  - `README.md` — Badminton Store identity, implemented flows, Flutter/Supabase stack, `.env.example` setup, run/quality/DB commands; no demo credentials or “replace fake adapters” instructions
  - `docs/architecture.md` — current bootstrap/`ConfigurationErrorApp`, wired feature repositories, `checkout_cod` boundary, Riverpod/MVVM/GoRouter, Notifications + facade limitations
  - `docs/coding_guidelines.md` — money guidance aligned with `double` VND snapshots + server authority; shop repos documented as wired (Notifications/facades excluded)
  - `supabase/README.md` — local verification checklist; no longer implies Flutter repository wiring is future Supabase work
  - Stale “later milestone” comments corrected on wired address/cart/catalog/favorites/orders/product/search repository interfaces and catalog providers; Notifications comments unchanged
- **Earlier (TASK-005):** `docs/backend/flutter_integration_notes.md` documents checkout RPC payload, estimate-only totals, sanitized errors, and success navigation.
- **Impact (historical):** Agents/humans following stale docs could mis-plan and re-implement existing adapters.
- **Recommendation:** Keep ADRs for decisions; keep status docs in sync when wiring changes.

### P1-4. Account routes registered but not linked from shell UI (including logout) — **RESOLVED (TASK-009)**

- **Verified paths:** routes in `lib/app/router/app_router.dart` / `app_routes.dart` for `/settings`, `/orders`, `/addresses`, `/notifications`; logout only in `lib/features/settings/presentation/views/settings_page.dart`.
- **Resolved in TASK-009:** authenticated Profile loaded state pushes `AppRoutes.orders`, `AppRoutes.addresses`, and `AppRoutes.settings` via `context.push` (shell Profile state preserved on back). Settings remains the owner of logout. Notifications stay intentionally unlinked until a backend/repository exists.
- **Impact (historical):** Authenticated users previously could not reach settings/logout, orders, or addresses through normal navigation (deep link only).

### P1-5. Missing Supabase config soft-skips init but hard-fails client providers — **RESOLVED (TASK-010)**

- **Verified paths:** `lib/app/bootstrap.dart` (`buildBootstrapRoot` gates on `SupabaseConfig.isConfigured` before initialize / `ProviderScope`), `lib/app/configuration_error_app.dart` (standalone configuration-error UX), `lib/core/supabase/supabase_initializer.dart` (still skips when unconfigured as a secondary path), `lib/core/supabase/supabase_providers.dart` (`supabaseClientProvider` remains fail-closed with `StateError` if not initialized).
- **Resolved in TASK-010:** Incomplete URL/key configuration selects `ConfigurationErrorApp` before the normal `App` and Supabase-dependent providers mount. Valid configuration initializes Supabase once and mounts the existing `ProviderScope` overrides unchanged. Initialization exceptions propagate and are not labeled as missing configuration. `supabaseClientProvider` stays a defensive fail-closed invariant.
- **Impact (historical):** Without env keys, splash session restore could fail hard / leave loading state instead of a clear configuration error.

---

## P2 — secondary / maintainability / coverage

### P2-1. Notifications feature is domain + placeholder only

- **Paths:** `lib/features/notifications/**`, `lib/shared/widgets/shop_placeholder_page.dart`; no `notifications` table under `supabase/migrations/`.
- **Impact:** Secondary feature; provider throws if wired prematurely.
- **Recommendation:** After commerce MVP, add schema + RLS + repository, then replace placeholder. **Still remaining.**

### P2-2. Generic `SupabaseDatabase` / `SupabaseStorage` providers unwired

- **Path:** `lib/core/supabase/supabase_providers.dart`
- **Impact:** Dead DI surface; repos bypass facades via `SupabaseClient`.
- **Recommendation:** Implement facades and migrate repositories, or delete unused providers to reduce trap hazards. **Still remaining (optional).**

### P2-3. Flutter tests for shop repositories / route guards — **MOSTLY RESOLVED (TASK-011–015, TASK-017)**

- **Checkout (TASK-005):** `test/features/checkout/` — RPC payload, sanitized failures, VM/widget flows.
- **Product variant select:** `test/features/product/supabase_product_repository_test.dart`.
- **TASK-011:** catalog + search repository regressions.
- **TASK-012:** favorites repository regressions.
- **TASK-013:** cart repository regressions.
- **TASK-014:** address repository regressions.
- **TASK-015:** order repository regressions.
- **TASK-017:** auth redirect policy + authenticated navigation regressions.
- **Still thin / absent:** notifications (intentional); broader Home storefront UX tests optional.
- **Impact:** Core commerce repository and nav regressions are covered in CI.
- **Recommendation:** Add Notifications coverage only after schema exists.

### P2-4. Money typing guidance vs entities disagree — **RESOLVED (TASK-018)**

- **Resolution:** `docs/coding_guidelines.md` documents PostgreSQL `numeric` as authoritative; Dart domain snapshots currently use `double` for whole VND display values; clients must not calculate trusted checkout/accounting totals; formatting stays in UI helpers (`PriceLabel` / `CurrencyConstants`). Matches entities and `docs/backend/flutter_integration_notes.md`.
- **Impact (historical):** Inconsistent contributor guidance; float risk if misused for accounting (server remains source of truth).

### P2-5. Addresses UI was a demo FAB — **RESOLVED (TASK-016)**

- **Resolved in TASK-016:** validated create/edit address form flow replaces the hard-coded demo FAB create path; success feedback and sanitized list errors covered in tests.
- **Impact (historical):** Functional smoke path only; poor real-user UX.

### P2-6. Stale inline comments on wired providers — **RESOLVED (TASK-018)**

- **Resolution:** Corrected “later milestone” comments on wired address/cart/catalog/favorites/orders/product/search repository interfaces and `catalog_providers.dart`. Notifications (and unwired core facades outside TASK-018 scope) retain unimplemented wording.
- **Impact (historical):** Local confusion during reviews.

### P2-7. Home still presents a generic dashboard, not storefront merchandising

- **Paths:** `lib/features/home/presentation/views/home_page.dart`, `supabase_home_remote_data_source.dart` (featured products as dashboard cards).
- **Impact:** Usable but not storefront-polished.
- **Recommendation:** Deferred UX work after commerce completeness. **Still remaining.**

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
| Flutter unit/widget | Auth, home, profile, settings, product, checkout, catalog, search, favorites, cart, addresses, orders, app bootstrap, route guards/nav | Notifications (intentional); optional Home polish |
| DB constraints | `00_constraints.sql` executable smoke | Broader invariant coverage optional |
| DB RLS / grants | Executable `01`–`05` + checkout concurrency | Keep suites green on policy changes |
| Manual / remote | Not run in this audit | No `supabase` remote commands by task rule |

---

## Ordered follow-up tasks

Small, dependency-ordered backlog (each should be its own implementation task):

1. ~~**Hide `cost_price` from public API**~~ — **done in TASK-002**.
2. ~~**Executable RLS/storage/RPC/privilege test suite**~~ — **done in TASK-006**; trigger-helper EXECUTE in TASK-007; Data API grants in TASK-008.
3. ~~**Trusted checkout backend**~~ — **done in TASK-004**.
4. ~~**Wire checkout UI to trusted API**~~ — **done in TASK-005**.
5. ~~**Profile navigation hub**~~ — **done in TASK-009**.
6. ~~**Bootstrap configuration failure UX**~~ — **done in TASK-010**.
7. ~~**Flutter repository tests**~~ — **done in TASK-011–015** (catalog/search/favorites/cart/addresses/orders); product/checkout covered earlier.
8. ~~**Validated address form**~~ — **done in TASK-016**.
9. ~~**Route-guard / authenticated navigation regressions**~~ — **done in TASK-017**.
10. ~~**Documentation cleanup**~~ — **done in TASK-018** (`README.md`, `docs/architecture.md`, `docs/coding_guidelines.md`, `supabase/README.md`, this audit, stale wired-repo comments).
11. **Notifications** — only after schema/RLS designed; then repository + UI (`P2-1`).
12. **Optional facade cleanup** — implement or remove `SupabaseDatabase` / `SupabaseStorage` providers (`P2-2`).
13. **Home storefront polish** — merchandising UX beyond dashboard cards (`P2-7`).

Any future schema change must use a **new** Supabase CLI migration and include database/RLS tests. Do not edit deployed migrations.

---

## Checks run

### TASK-018 (this task)

| Check | Result |
|-------|--------|
| `dart format --output=none --set-exit-if-changed` (scoped Dart comment files) | Passed — 9 files, 0 changed |
| `flutter analyze` | Passed — no issues |
| `flutter test` | Passed — all tests (+228) |
| `git diff --check` | Passed |
| `python3 scripts/automation.py policy-check` | Passed |

No schema, migration, RLS, auth, router, repository behavior, or dependency changes. Comment-only Dart edits; Markdown documentation refresh only.

### Historical — TASK-010 (Supabase configuration failure UX)

| Check | Result |
|-------|--------|
| `dart format` (changed Dart files) | Passed — `bootstrap.dart`, `configuration_error_app.dart`, `bootstrap_test.dart`, `configuration_error_app_test.dart` |
| `flutter analyze` | Passed — no issues |
| `flutter test test/app` | Passed — bootstrap root-selection + configuration-error UX tests |
| `flutter test` | Passed — all tests |
| `python3 scripts/automation.py policy-check` | Passed |

No schema, migration, RLS, auth, router, repository, or feature behavior changes. `supabaseClientProvider` fail-closed guard unchanged.

### Historical — TASK-009 (Profile account navigation hub)

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

## Remaining work (out of scope for TASK-018)

- Notifications schema + repository + UI (`P2-1`)
- Optional `SupabaseDatabase` / `SupabaseStorage` facade cleanup (`P2-2`)
- Home storefront polish (`P2-7`)
- Remote apply of prior migrations remains post-approval/merge only (this task changes no migrations)
