# Architecture — Badminton Shop

## Purpose

This document describes the production architecture prepared by the
**Shop Foundation** milestone. It extends the existing feature-first Flutter
base without replacing established systems.

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
| Backend (planned) | Supabase (Auth, PostgREST, Storage) |

## Layers

```
presentation  →  ViewModels call repositories / selective use cases
domain        →  entities + repository interfaces (+ use cases when needed)
data          →  models, data sources, repository implementations
core          →  shared infrastructure (network, storage, supabase, errors)
shared        →  cross-feature session, mappers, shop widgets
```

## Feature map

| Feature | Owns |
|---------|------|
| `authentication` | Sign-in, session restore (`AuthRepository`, `User`) |
| `home` | Landing / dashboard shell |
| `catalog` | Categories, brands |
| `product` | Products, variants, images |
| `cart` | Cart aggregate |
| `checkout` | Checkout orchestration (payment adapters later) |
| `orders` | Order history |
| `favorites` | Wishlist |
| `profile` | Customer profile |
| `addresses` | Shipping / billing addresses |
| `search` | Product search |
| `notifications` | In-app notifications |
| `settings` | Appearance / preferences |

## Repositories

Repositories are the **only** boundary between presentation and infrastructure.

- Interfaces live in `domain/repositories/`.
- Implementations live in `data/repositories/` (not yet for shop features).
- Methods return `Future<Result<T>>`.
- Presentation imports providers from `di/`, never concrete data sources.

Existing auth/profile repositories remain the source of truth for identity.
Shop providers currently throw `UnimplementedError` until Supabase adapters land.

### Naming note

`AuthRepository` is the authentication contract (listed as
`AuthenticationRepository` in planning docs). Do not introduce a second auth
repository.

## Supabase integration plan

```
bootstrap
  → dotenv + SharedPreferences
  → (later) SupabaseInitializer.initialize(SupabaseConfig)
  → Pending session manager → real SupabaseSessionManager

feature repository impl
  → SupabaseDatabase / SupabaseAuthDataSource / SupabaseStorage
  → SupabaseExceptionMapper → AppException
  → map Freezed models → domain entities
  → Result.success / Result.failure
```

Shop Foundation ships:

- `SupabaseConfig`, `SupabaseInitializer` (pending no-op)
- `SupabaseAuthDataSource`, `SupabaseDatabase`, `SupabaseStorage` (interfaces)
- `SupabaseExceptionMapper`, `SupabaseSessionManager`
- Riverpod providers under `core/supabase/`

No `supabase_flutter` network calls are made yet. Env placeholders:
`SUPABASE_URL`, `SUPABASE_ANON_KEY`.

## Routing

Shell tabs: **Home · Catalog · Cart · Favorites · Profile**

Push routes: product detail, checkout, orders, addresses, search, settings,
notifications.

Auth redirect continues to gate unauthenticated access via
`authSessionProvider`.

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

## What this milestone deliberately excludes

- Product / cart / checkout / order business logic
- Fake shop repositories and mock catalogs
- Real Supabase API calls and SQL
- Full authentication / shop screen implementations
