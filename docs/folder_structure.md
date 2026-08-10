# Folder structure

```
lib/
├── main_development.dart
├── main_staging.dart
├── main_production.dart
├── app/
│   ├── app.dart
│   ├── bootstrap.dart
│   ├── router/
│   │   ├── app_router.dart
│   │   ├── app_routes.dart
│   │   └── route_refresh_notifier.dart
│   └── theme/
├── core/
│   ├── config/
│   ├── constants/          # pagination, cache, currency, limits, …
│   ├── database/           # local cache hooks (reserved)
│   ├── errors/
│   ├── extensions/
│   ├── logging/
│   ├── network/
│   ├── permissions/        # OS permission keys (reserved)
│   ├── result/
│   ├── storage/
│   ├── supabase/           # config + initializer + contracts
│   ├── utils/
│   ├── widgets/
│   └── ui/
│       ├── animations/
│       ├── glass/
│       └── responsive/
├── features/
│   ├── authentication/
│   ├── home/
│   ├── catalog/
│   ├── product/
│   ├── cart/
│   ├── checkout/
│   ├── orders/
│   ├── favorites/
│   ├── profile/
│   ├── addresses/
│   ├── search/
│   ├── notifications/
│   ├── settings/
│   └── design_system/
└── shared/
    ├── data/
    ├── providers/
    ├── session/
    └── widgets/
        ├── app_scaffold.dart
        ├── shop_placeholder_page.dart
        └── shop/             # ProductCard, PriceLabel, …
```

## Feature layout

Every shop feature follows:

```
features/<name>/
├── di/<name>_providers.dart
├── data/
│   ├── data_sources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── use_cases/          # only when needed
└── presentation/
    ├── view_models/
    ├── views/
    └── widgets/
```

Empty layers keep a `.gitkeep` so the tree is visible in git until files land.

## Domain ownership

| Entity | Feature |
|--------|---------|
| `User` | `authentication` |
| `Profile` | `profile` |
| `Category`, `Brand` | `catalog` |
| `Product`, `ProductVariant`, `ProductImage` | `product` |
| `Cart`, `CartItem` | `cart` |
| `Favorite` | `favorites` |
| `Order`, `OrderItem` | `orders` |
| `Address` | `addresses` |
| `AppNotification` | `notifications` |

## Core constants

| File | Role |
|------|------|
| `pagination_constants.dart` | Page sizes |
| `cache_keys.dart` | Logical cache prefixes |
| `image_sizes.dart` | Thumbnail / card / hero sizes |
| `animation_durations.dart` | Commerce micro-interactions |
| `api_limits.dart` | Client-side soft limits |
| `currency_constants.dart` | Default VND display |
| `date_formats.dart` | Display / ISO patterns |
| `product_constants.dart` | Supported category slugs |
| `storage_keys.dart` | Secure / prefs keys |
| `api_constants.dart` | Timeouts |

## Docs

| File | Audience |
|------|----------|
| `docs/architecture.md` | System overview |
| `docs/folder_structure.md` | This map |
| `docs/coding_guidelines.md` | Conventions |
| `docs/feature_workflow.md` | How to add a feature |
| `docs/architecture/00x-*.md` | Historical ADRs |
