# 004 — Result and error handling

## Context

Throwing raw exceptions through the presentation layer couples UI to Dio and
storage failures. Silent `catch` blocks hide bugs.

## Decision

- Repositories return `Result<T>` (`Success` / `Failure`) using sealed classes.
- Infrastructure exceptions are mapped to `AppException` subtypes via
  `ErrorMapper`.
- Unexpected errors are logged with stack traces.
- Views and ViewModels never parse `DioException` directly.

## Consequences

- Exhaustive `switch` handling at call sites.
- Clear user-facing messages without leaking transport details.
- Slightly more ceremony than throwing exceptions everywhere.

## Alternatives considered

- Exception-only flow with `try/catch` in ViewModels.
- `Either` from dartz / fpdart — powerful, but heavier dependency for a starter.
