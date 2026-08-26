# Feature workflow

How to grow the badminton shop after Shop Foundation.

## 1. Pick or create the feature folder

```
lib/features/<name>/
  data/{data_sources,models,repositories}/
  domain/{entities,repositories,use_cases}/
  presentation/{view_models,views,widgets}/
  di/
```

Reuse an existing feature when the domain already owns the concept
(e.g. extend `product`, do not create `product_details`).

## 2. Domain first

1. Add / extend immutable entities.
2. Extend the repository interface with `Result`-returning methods.
3. Add a use case **only if** you need validation, multi-repo orchestration,
   or a reusable domain action.

## 3. Data layer

1. Add Freezed models + `fromJson` for Supabase / API payloads.
2. Declare remote (and optional local) data source interfaces.
3. Implement `FooRepositoryImpl`:
   - check connectivity when needed
   - call data sources
   - map models → entities
   - map errors via `ErrorMapper` / `SupabaseExceptionMapper`
4. Register the impl in `di/<name>_providers.dart` (replace any temporary
   throw-on-read stubs only when a real implementation is ready).

## 4. Supabase wiring (when ready)

1. Fill `SUPABASE_URL` / publishable (or legacy anon) key in env files or
   dart-defines — never a service-role key.
2. Ensure bootstrap initializes Supabase when configured (incomplete config
   selects `ConfigurationErrorApp`).
3. Wire feature repositories through `supabaseClientProvider` (and
   `supabaseAuthDataSourceProvider` when auth-specific). Do not reintroduce
   unused generic DB/Storage facades.
4. Expand `SupabaseExceptionMapper` for Auth / PostgREST / Storage codes.
5. Keep RLS and SQL in Supabase — not in the Flutter app.

## 5. Presentation

1. Sealed UI state + `StateNotifier` ViewModel.
2. Page using `GlassBackground` / glass widgets / shop shared widgets.
3. Register the route in `AppRoutes` + `app_router.dart`.
4. Shell tab only for primary destinations; use push routes for detail flows.

## 6. Tests

1. Unit-test repository mapping and error paths with mocked data sources.
2. Unit-test ViewModels with overridden repository providers.
3. Widget-test critical pages with `ProviderScope` overrides.

## Checklist for a new shop capability

- [ ] Entity(ies) in the owning feature
- [ ] Repository method(s) on the interface
- [ ] Freezed model(s) + mapper
- [ ] Data source + repository impl
- [ ] Provider registration
- [ ] ViewModel + page (or extend existing)
- [ ] Route (if new screen)
- [ ] Tests
- [ ] `dart format` + `flutter analyze` + `flutter test`

## Example: “Add product reviews” later

1. Prefer `features/product/` (reviews belong to product).
2. Add `ProductReview` entity + `ProductRepository` methods (or a dedicated
   `ReviewRepository` if lifecycle diverges).
3. Supabase table + RLS → repository queries via `supabaseClientProvider`.
4. UI under `product/presentation/` using `GlassCard` / existing tokens.
5. No new top-level architecture modules required.
