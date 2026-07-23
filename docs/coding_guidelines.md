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
- Don't commit real `SUPABASE_ANON_KEY` / secrets to git.
- Don't add fake shop repositories in foundation milestones unless asked.

## Naming

| Kind | Pattern |
|------|---------|
| Page | `FooPage` / `foo_page.dart` |
| ViewModel | `FooViewModel` + `FooState` |
| Repository interface | `FooRepository` |
| Repository impl | `FooRepositoryImpl` |
| Remote DS | `FooRemoteDataSource` |
| Model | `FooModel` (`@freezed`) |
| Provider file | `foo_providers.dart` |

## Money

- Store amounts as `int` minor units on entities (`priceAmount`, `totalAmount`).
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
- Unwired shop repositories may throw `UnimplementedError` until adapters exist.
- Override providers in tests via `createTestContainer` helpers.

## Analysis

Follow `very_good_analysis` with project overrides in `analysis_options.yaml`.
Run `dart format` and `flutter analyze` before merging.
