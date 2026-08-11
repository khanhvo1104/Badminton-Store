# Coding guidelines

## Do

- Keep features independent; share only through `core/` and `shared/`.
- Put business rules in domain (entities / selective use cases).
- Return `Result<T>` from repositories; never throw into ViewModels.
- Use Freezed for **data models** (JSON DTOs), not for domain entities or UI state.
- Use plain `@immutable` classes for domain entities (match existing `User`).
- Wire dependencies in `features/<name>/di/*_providers.dart`.
- Prefer Liquid Glass widgets on shop screens.
- Prefer existing theme tokens (`AppSpacing`, `AppColors`, `AppMotion`).
- Keep ViewModels thin: load → map `Result` → emit sealed state.

## Don't

- Don't import `data/` types into `presentation/`.
- Don't call Dio or Supabase from widgets / ViewModels.
- Don't add one-liner use cases for every CRUD method (see ADR 003).
- Don't invent a second auth session or router.
- Don't Freezed UI state; use sealed classes like `LoginState`.
- Don't commit real `SUPABASE_PUBLISHABLE_KEY` / `SUPABASE_ANON_KEY` / secrets to git.
- Don't embed a Supabase `service_role` or other secret key in Flutter.
- Don't trust client-calculated checkout totals, inventory, or privileged order transitions — those stay server-side (RLS / `checkout_cod`).

## Naming

| Kind | Pattern |
|------|---------|
| Page | `FooPage` / `foo_page.dart` |
| ViewModel | `FooViewModel` + `FooState` |
| Repository interface | `FooRepository` |
| Repository impl | `FooRepositoryImpl` / `SupabaseFooRepository` |
| Remote DS | `FooRemoteDataSource` |
| Model | `FooModel` (`@freezed`) |
| Provider file | `foo_providers.dart` |

## Money

- **PostgreSQL `numeric` is authoritative** for prices, line totals, and order
  amounts (see migrations and `checkout_cod`).
- **Dart domain snapshots currently use `double`** for whole VND values used in
  UI/display (e.g. `ProductVariant.price`, cart/order amount fields). This is a
  presentation/snapshot convention, not a license to do accounting in the client.
- **Clients must not calculate trusted checkout or accounting totals.** Cart and
  checkout UI amounts are estimates; the server re-prices and persists totals.
- Default display currency is VND (`CurrencyConstants`).
- Format only in UI helpers such as `PriceLabel`.

## Errors

Map infrastructure failures at the data boundary:

1. Catch SDK / Dio / storage errors.
2. Convert with `ErrorMapper` or `SupabaseExceptionMapper`.
3. Return `Failure(exception)`.
4. Let the ViewModel choose user-facing copy.

## Riverpod

- Feature ViewModels: `StateNotifierProvider.autoDispose`.
- Session / appearance: long-lived providers.
- Commerce feature repositories are wired to Supabase implementations via
  `di/*_providers.dart`. **Notifications** and the generic
  `supabaseDatabaseProvider` / `supabaseStorageProvider` facades remain
  unimplemented and throw if read.
- Override providers in tests via `createTestContainer` helpers.

## Analysis

Follow `very_good_analysis` with project overrides in `analysis_options.yaml`.
Run `dart format` and `flutter analyze` before merging.
