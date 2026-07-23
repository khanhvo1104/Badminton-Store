# 005 — Environment configuration

## Context

Development, staging, and production need different API bases and logging
flags without scattering `if (kDebugMode)` checks across features.

## Decision

Provide three entry points (`main_development.dart`, `main_staging.dart`,
`main_production.dart`) that call `bootstrap(AppEnvironment)`. Environment
values load from example `.env.*` files into a single `AppConfig` exposed via
Riverpod.

## Consequences

- Features read `appConfigProvider` instead of hardcoding environment checks.
- Secrets stay out of source; only placeholders are committed.
- Running the wrong entry point is the main misconfiguration risk.

## Alternatives considered

- Compile-time `--dart-define` only: works well in CI, less friendly locally.
- Flavor-specific Android/iOS projects without Dart entry points: more native
  setup for little gain in this starter.
