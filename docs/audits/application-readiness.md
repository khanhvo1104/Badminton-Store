# Application readiness audit — Badminton Store

| Field | Value |
|-------|--------|
| Audit date | 2026-08-26 |
| Task | TASK-046 (readiness re-audit after TASK-045; CMS roadmap complete through TASK-044) |
| Scope | Evidence-backed current baseline + small next backlog; Markdown / `.automation` metadata only |
| Method | Repository inspection (`rg`, migrations, tests, CI history, docs); no Flutter/CMS/Supabase suite re-runs; no remote Supabase commands; no hosted-dashboard claims without repo proof |
| Prior audit | 2026-08-11 (TASK-018) — superseded for status claims; useful security/test evidence retained below |

## Verdict

**Customer COD commerce MVP and staff CMS product/ops surface are implemented in-repo end-to-end.** Flutter covers auth → browse → cart → trusted `checkout_cod` → orders/addresses/profile, plus wired in-app notifications (TASK-019–022) and a navigable Home storefront (TASK-023). Unused generic Supabase facades are gone (TASK-045). The Next.js CMS covers auth, catalog CRUD, inventory, media, orders, dashboard, staff, audit trail, Playwright readiness, and deployment health/smoke/backup-rehearsal tooling (TASK-024–044). Local DB suites `00`–`14` plus Flutter/CMS CI exist; latest `develop` CI (merge of PR #77 / TASK-045, run `32716606367`) concluded **success**.

**No repository-evident release blockers** in application code for the COD + CMS MVP path. Remaining work is mainly (1) a hollow notifications *producer* gap, (2) optional maintenance, and (3) **human/external** production configuration that this repository cannot prove.

---

## Verified subsystem matrix

| Subsystem | UI | Provider / repo wiring | Backend (migrations) | Tests | Notes |
|-----------|----|------------------------|----------------------|-------|-------|
| Bootstrap / env | `ConfigurationErrorApp` when unconfigured | Overrides in `lib/app/bootstrap.dart` | N/A | `test/app/` | Expected override-or-throw DI for env/prefs |
| Authentication | Login, splash | Supabase Auth + secure storage | Auth → profiles trigger | `test/features/authentication/` | |
| Home | Shell tab storefront | Featured `product_catalog` | Catalog view | `test/features/home/` | TASK-023 — product/catalog/search entry points |
| Catalog / product / search | Shell + push | Supabase repos + RPCs | RLS + views/RPCs | Repo + product select tests | `cost_price` column lockdown preserved |
| Favorites / cart / checkout | Shell + `/checkout` | Supabase repos; checkout → `checkout_cod` only | Own-row RLS + SECURITY DEFINER RPC | TASK-005/012/013 tests | Client totals are estimates |
| Orders / addresses / profile / settings | Push + Profile hub | Supabase repos | Own SELECT / CRUD RLS | TASK-009/014–017 | Logout on Settings |
| Notifications | `/notifications` + Profile entry + unread badge | `SupabaseNotificationRepository` | `public.notifications` + owner RLS/grants | `test/features/notifications/` + suite `06` | **Consumers wired; no in-repo trusted writer** (see Current gaps) |
| Supabase core DI | N/A | `supabaseClientProvider`; no generic DB/Storage facades | Migrations present | Bootstrap tests | TASK-045 removed facade trap |
| Storage | N/A | Feature / client `.storage` | Buckets + policies | Suite `01` SIUD | Public catalog read; staff write; avatar ownership |
| CMS auth / shell | Next.js App Router | SSR cookies + `getClaims()` + `profiles.role` | Trusted role helpers | Vitest + Playwright | No CMS self-signup |
| CMS catalog / inventory / media | Dashboard routes | Server Actions + RPCs | TASK-026–038 migrations | Unit + DB `07`–`10` | Product-management MVP complete |
| CMS orders / dashboard / staff / audit | Dashboard routes | Trusted RPCs + Edge invite finalize | TASK-039–042 migrations | Unit + DB `11`–`14` + concurrency | Milestone 3 complete |
| CMS ops readiness | `/api/health`, `/api/ready`, smoke CLI | Local backup rehearsal script | N/A (local only) | TASK-043/044 CI jobs | Does **not** prove hosted SMTP/PITR/Vercel checks |
| Route guards / nav | Shell + push | `auth_redirect_policy.dart` | N/A | TASK-017 | Unauth redirect + hub links |
| Design system | Debug `/design-system` | N/A | N/A | Glass widget tests | `kDebugMode` gated |

---

## Old P2 items (2026-08-11) — disposition

| ID | Claim (2026-08-11) | 2026-08-26 disposition | Evidence |
|----|--------------------|------------------------|----------|
| P2-1 | Notifications placeholder / no table / provider throws | **Resolved for consumer path** (TASK-019–022). Producer gap remains (below). | Migration `20260811042236_notifications_backend.sql`; `lib/features/notifications/**`; Profile `profile_account_notifications`; suite `06` |
| P2-2 | Generic `SupabaseDatabase` / `SupabaseStorage` `UnimplementedError` providers | **Resolved** (TASK-045) | Facades deleted; repos use `supabaseClientProvider` |
| P2-3 | Thin Flutter shop/nav tests | **Resolved** for commerce + notifications/home | `test/features/**`; CI Flutter job |
| P2-4 | Money guidance vs entities | **Resolved** (TASK-018 docs) | `docs/coding_guidelines.md` — `double` display snapshots; server authoritative |
| P2-5 | Addresses demo FAB | **Resolved** (TASK-016) | Validated address form |
| P2-6 | Stale “later milestone” comments | **Resolved** (TASK-018); facades later removed | Wired repo comments |
| P2-7 | Home generic dashboard | **Resolved** (TASK-023) | `home_page.dart` + featured cards + nav tests |

### Configuration / override stubs (still real, expected)

| Site | Behavior | Impact |
|------|----------|--------|
| `lib/core/config/environment_provider.dart` | `UnimplementedError` unless overridden | Overridden in bootstrap/tests — DI pattern, not a product gap |
| `lib/core/storage/storage_providers.dart` | Same for SharedPreferences | Same |
| `PendingSupabaseSessionManager` | Soft placeholder when session manager not initialized | Client provider remains fail-closed if Supabase not initialized |

`ShopPlaceholderPage` remains in `lib/shared/widgets/shop_placeholder_page.dart` with **no Dart callers** after notifications shipping — optional dead-code cleanup only.

---

## Current gaps (concrete only)

### Release blockers (code)

**None identified in-repository** for authenticated COD checkout + staff CMS MVP, assuming operators apply migrations and configure hosted projects (human).

### Code backlog

1. **Hollow notifications producer** — Customers can list/mark-read, but no migration/CMS/Flutter path inserts `public.notifications` rows. `checkout_cod` and `transition_cms_order_status` do not write notifications. Content creation is documented as `service_role`/trusted backend only (`docs/backend/notifications_security.md`), yet no trusted writer exists in-repo. → **TASK-047**.
2. **Order-update notification navigation** — TASK-021 intentionally omitted payload-driven navigation; Flutter has `/orders` list only (no order-detail route). After producers exist, tapping an `order_update` can at least open `/orders`. → **TASK-048** (depends on TASK-047 payload contract).

### Optional maintenance

- Delete unused `ShopPlaceholderPage` if desired (no behavior change).
- Broader Dart money typing (`double` → decimal-like) — display-only risk; server remains source of truth; not queued.
- Push / Realtime / email / SMS notifications — explicitly out of historical notifications backend scope; speculative; not queued.
- Non-COD payment rails — product expansion; not queued.

### Human / external configuration (not executable automation tasks)

Repository evidence ships **runbooks and local rehearsals only**. Do **not** assume these are configured in any hosted project:

| Item | Repo evidence | Hosted state |
|------|---------------|--------------|
| Custom SMTP for Auth invite/recovery | Checklist in `docs/cms/operations-runbook.md` | **Unproven** |
| Vercel Deployment Checks / production domain | Runbook HUMAN steps | **Unproven** |
| Monitoring / uptime alerts on `/api/health` + `/api/ready` | Suggested thresholds in runbook | **Unproven** |
| Hosted backups / PITR / RPO–RTO | Local `scripts/cms-backup-rehearsal.sh` only | **Unproven** |
| Remote migration apply to staging/production | Migrations in git; no remote commands in this audit | **Operator-owned** |
| Initial CMS admin profile | Docs: manual promote — no self-signup | **Operator-owned** |
| Production env vars (Vercel + Supabase URL/publishable key) | `cms/.env.example` placeholders only | **Operator-owned** |

See operations checklist below and `docs/cms/operations-runbook.md`.

---

## Security boundaries (still in force)

1. **Flutter/CMS browsers may only use publishable/anon keys** — never service-role in clients (`AGENTS.md`, `supabase_config`, CMS env contract).
2. **Authorization via trusted `public.profiles.role`** (`is_staff_or_admin` / `is_admin`) and `prevent_profile_privilege_escalation` — not user-editable JWT metadata. Trigger-helper EXECUTE locked (TASK-007).
3. **Checkout does not trust client totals** — `public.checkout_cod` re-prices, reserves inventory, snapshots, converts cart (`docs/backend/checkout_security.md`).
4. **`product_variants.cost_price`** — no table-wide SELECT for `anon`/`authenticated`; staff cost via `get_staff_variant_costs` (TASK-002/026). Suite `02` / `07`.
5. **Inventory raw table staff-oriented**; public stock via availability helpers/views.
6. **Storage** — public catalog read; staff write; avatar ownership (suite `01`).
7. **CMS privileged mutations** — trusted RPCs, staff/admin gates, immutable audit trail (TASK-042) with service-role table lockdown follow-ups.
8. **Notifications** — owner SELECT + `UPDATE(is_read)` only; no customer INSERT/DELETE (suite `06`).

---

## Test / CI baseline (honest)

| Layer | What exists | This audit ran |
|-------|-------------|----------------|
| Flutter unit/widget | Auth, home, catalog, search, product, favorites, cart, checkout, orders, addresses, profile, settings, notifications, bootstrap, nav | **Not re-run** (docs-only task) — rely on CI |
| CMS unit/contract | Vitest across features + health/ready/smoke | **Not re-run** — rely on CI |
| CMS Playwright | Production-readiness suite in `cms-e2e` job | **Not re-run** — rely on CI |
| DB `00`–`14` (+ concurrency / postgrest scripts) | Local disposable stack | **Not re-run** — no migration changes |
| GitHub CI on `develop` | Flutter + CMS + cms-e2e | Latest success: PR #77 merge (`ceff902…`, run `32716606367`, 2026-08-24) |

TASK-046 verification: JSON validate, `python3 scripts/automation.py policy-check`, `git diff --check` only.

---

## Historical resolutions (compact)

| Theme | Tasks | Pointers |
|-------|-------|----------|
| `cost_price` lockdown | TASK-002 | `…protect_product_variant_cost_price.sql`, suite `02` |
| Trusted COD checkout | TASK-004/005 | `…trusted_cod_checkout.sql`, suite `03` + concurrency |
| RLS / grants / trigger EXECUTE | TASK-006–008 | Suites `01`, `04`, `05` |
| Profile hub / config UX / repo tests / address form / nav tests / docs | TASK-009–018 | Flutter `test/` + docs |
| Notifications backend → UI → Profile | TASK-019–022 | Migration + Flutter feature + suite `06` |
| Home storefront | TASK-023 | `test/features/home/` |
| CMS foundation → ops | TASK-024–044 | `cms/`, migrations through audit trail, Playwright, health/smoke/backup rehearsal |
| Remove unused Supabase facades | TASK-045 | Core DI cleanup |

Full narrative for early P0/P1 items remains in git history of this file (pre–TASK-046); do not treat 2026-08-11 “remaining P2” bullets as current.

---

## Ordered next backlog

1. **TASK-047** — Emit owner-scoped `order_update` rows from trusted order lifecycle writers (`checkout_cod`, `transition_cms_order_status`) with DB regressions. High risk; migration-only producer; no Flutter/CMS UI expansion.
2. **TASK-048** — After TASK-047 payload contract: Flutter notification tap navigates to `/orders` for `order_update` (sanitized; no new order-detail route). Medium risk.

Human production cutover stays on the checklist below — not automation tasks.

---

## Operations checklist (human / external)

Operators must complete outside git (dashboard/CLI with secrets). Record evidence in release tickets; never commit secrets.

- [ ] Separate staging vs production Supabase projects and matching CMS env
- [ ] Apply pending migrations to each hosted project in controlled windows
- [ ] Set Vercel Production branch / root `cms/` / env vars; optional Deployment Checks
- [ ] Configure Custom SMTP + Auth redirect allow-list for CMS password recovery / invites
- [ ] Promote initial active `admin` profile (no CMS self-signup)
- [ ] Wire uptime probes to `/api/health` and `/api/ready`; agree 5xx alert thresholds
- [ ] Confirm hosted backup tier / PITR; schedule quarterly restore into **non-production**
- [ ] Post-deploy: `node cms/scripts/smoke-check.mjs --base-url https://<host>`
- [ ] Flutter storefront production env: publishable URL/key only

---

## Checks run (TASK-046)

| Check | Result |
|-------|--------|
| Repository-wide stub/`TODO`/`UnimplementedError` evidence (`rg`) | Passed — only expected override providers + unused `ShopPlaceholderPage` |
| JSON parse of `.automation/backlog.json` | Passed |
| `python3 scripts/automation.py policy-check` | Passed |
| `git diff --check` | Passed |
| Flutter analyze / test | **Skipped** — no Dart/app changes; baseline = current `develop` CI |
| CMS lint/test/e2e | **Skipped** — no CMS/app changes; baseline = current `develop` CI |
| Supabase db suites / remote | **Skipped** — no migrations; no remote commands |

No schema, application behavior, workflow, dependency, lockfile, env, or secret changes.
