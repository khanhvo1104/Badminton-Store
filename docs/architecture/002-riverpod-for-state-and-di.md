# 002 — Riverpod for state and DI

## Context

The presentation layer needs reactive state, and the data layer needs
dependency injection. Using two frameworks (for example GetIt + Bloc) increases
boilerplate and obscures the dependency graph.

## Decision

Use Riverpod as the single mechanism for both state management and dependency
injection. Providers wire repositories, use cases, and ViewModels. Feature
state uses `StateNotifier` (or generated Notifiers when beneficial) with
immutable sealed states.

## Consequences

- Overrides make testing straightforward (`ProviderContainer` / `ProviderScope`).
- No global service locator; dependencies are explicit and scoped.
- Presentation can depend on provider contracts without importing Dio or
  storage plugins.

## Alternatives considered

- GetIt + Injectable: powerful but introduces a second DI paradigm.
- Bloc/Cubit: excellent for event-driven flows, but adds another library when
  Riverpod already covers state + DI.
