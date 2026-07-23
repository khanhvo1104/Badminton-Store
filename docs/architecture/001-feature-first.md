# 001 — Feature-first organization

## Context

Medium and large Flutter apps become hard to navigate when organized only by
technical layers (`models/`, `screens/`, `services/`). Features evolve at
different rates and are owned by different teams.

## Decision

Organize code by feature first (`features/authentication`, `features/home`, …),
with `data`, `domain`, and `presentation` folders inside each feature. Shared
infrastructure lives in `core/` and cross-cutting UI/providers in `shared/`.

## Consequences

- Feature ownership is clear and files that change together stay together.
- Circular imports between features are easier to spot and forbid.
- Some shared concepts (for example `User`) must be carefully placed in domain
  or `shared/` rather than duplicated.

## Alternatives considered

- Layer-first (`data/`, `domain/`, `presentation/` at the root): simpler for
  tiny apps, but scales poorly.
- Package-per-feature monorepo: excellent isolation, higher setup cost for a
  starter.
