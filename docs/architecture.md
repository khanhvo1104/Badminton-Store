# Architecture — Badminton Store

## Purpose

This document describes the **current** production-oriented architecture of the
Badminton Store Flutter client and its Supabase backend boundary. It reflects
wired commerce/auth features, not the earlier Shop Foundation “planned only”
milestone.

## Stack

| Concern | Choice |
|--------|--------|
| Organization | Feature-first (`features/<name>/`) |
| Presentation | MVVM (`View` → `ViewModel` → repository) |
| State + DI | Riverpod |
| Navigation | go_router (+ auth redirect) |
| Domain errors | `Result<T>` + sealed `AppException` |
| DTOs | Freezed + json_serializable |
| Domain entities | Immutable plain classes (`@immutable`) |
| UI | Liquid Glass design system |
| Backend | Supabase (Auth, PostgREST, Storage, RPCs) |

## Layers

```
presentation  →  ViewModels call repositories / selective use cases
domain        →  entities + repository interfaces (+ use cases when needed)
data          →  models, data sources, repository implementations
core          →  shared infrastructure (config, storage, supabase, errors)
shared        →  cross-feature session, mappers, shop widgets
```

## Bootstrap and configuration

```
main_* → bootstrap(AppEnvironment)
  → dotenv.load(env file)
  → SharedPreferences
  → loadSupabaseConfig (URL + publishable/legacy anon key)
  → if !isConfigured → ConfigurationErrorApp (no ProviderScope / no init)
  → else FlutterSupabaseInitializer.initialize → ProviderScope → App
```

- Incomplete Supabase URL/key shows explicit configuration-error UX
  (`lib/app/configuration_error_app.dart`) instead of mounting shop providers.
- `supabaseClientProvider` remains fail-closed (`StateError`) if a caller
  reaches it without a successful initialize (defensive invariant).
- Flutter may use only publishable or legacy anon keys — never `service_role`
  or other secrets (`lib/core/supabase/supabase_config.dart`, `AGENTS.md`).

## Feature map

| Feature | Owns | Wiring |
|---------|------|--------|
| `authentication` | Sign-in, session restore | Supabase Auth DS + secure storage |
| `home` | Landing / featured products | `SupabaseHomeRemoteDataSource` |
| `catalog` | Categories, brands | `SupabaseCategoryRepository` / `SupabaseBrandRepository` |
| `product` | Products, variants, images | `SupabaseProductRepository` |
| `cart` | Cart aggregate | `SupabaseCartRepository` |
| `checkout` | COD placement | `SupabaseCheckoutRepository` → `checkout_cod` |
| `orders` | Order history (read) | `SupabaseOrderRepository` |
| `favorites` | Wishlist | `SupabaseFavoriteRepository` |
| `profile` | Customer profile | Supabase profile DS + use case |
| `addresses` | Shipping / billing addresses | `SupabaseAddressRepository` |
| `search` | Product search | `SupabaseSearchRepository` |
| `settings` | Appearance / logout | Local prefs + auth logout |
| `notifications` | In-app notifications | **Placeholder only** — provider throws |

## Repositories

Repositories are the **only** boundary between presentation and infrastructure.

- Interfaces live in `domain/repositories/`.
- Implementations live in `data/repositories/` and are registered in
  `features/<name>/di/*_providers.dart`.
- Methods return `Future<Result<T>>`.
- Presentation imports providers from `di/`, never concrete data sources.
- Most shop features call `supabaseClientProvider` directly from repository
  implementations (generic `SupabaseDatabase` / `SupabaseStorage` facades in
  `core/supabase/` remain unwired and throw if read).

### Naming note

`AuthRepository` is the authentication contract (listed as
`AuthenticationRepository` in some planning docs). Do not introduce a second
auth repository.

## Trusted checkout boundary

COD checkout must not trust client prices or totals.

- Flutter calls only `rpc('checkout_cod', …)` with
  `p_shipping_address_id` and optional normalized `p_customer_note`.
- The SECURITY DEFINER RPC re-reads variant prices, reserves inventory,
  snapshots order/items/address, and converts the active cart server-side.
- Displayed cart/checkout amounts are **estimates** for UX; authoritative
  totals live in PostgreSQL / the RPC.
- Customers cannot INSERT orders or mutate inventory through table RLS;
  staff/admin writes use trusted `profiles.role` helpers, not JWT metadata.

See `docs/backend/checkout_security.md` and
`docs/backend/flutter_integration_notes.md`.

## Routing

Shell tabs: **Home · Catalog · Cart · Favorites · Profile**

Push routes: product detail, checkout, orders, addresses, search, settings,
notifications (placeholder; not linked from Profile until a backend exists).

Auth redirect continues to gate unauthenticated access via
`authSessionProvider` / `auth_redirect_policy.dart`.

Authenticated Profile links to orders, addresses, and settings (logout lives
on Settings).

## Error model

Typed exceptions in `core/errors/app_exception.dart`:

- `AuthenticationException`
- `NetworkException`
- `DatabaseException`
- `UnauthorizedException`
- `ValidationException`
- `StorageException`
- `ServerException`
- `CacheException`
- `UnknownException`

Map Dio via `ErrorMapper`. Map Supabase via `SupabaseExceptionMapper`.

## Design system

Reuse Liquid Glass (`core/ui/glass/`) and app theme tokens (`app/theme/`).

Commerce widgets live in `shared/widgets/shop/` (product card, price label,
badges, etc.) so catalog/product/cart can share UI without circular imports.

## Known limitations (intentional)

- **Notifications** — placeholder page; no `notifications` table; repository
  provider throws `UnimplementedError` if read.
- **Generic Supabase DB/Storage facades** — interfaces/providers exist but are
  unwired; feature repositories use `SupabaseClient` directly.
- **Home UX** — featured products as dashboard-style cards, not a full
  merchandising storefront.
- **Money in Dart** — domain snapshots use `double` for whole VND display
  values; PostgreSQL `numeric` and `checkout_cod` remain authoritative for
  accounting (see `docs/coding_guidelines.md`).
