# 003 — Selective use cases

## Context

Strict Clean Architecture often creates a one-line use case per repository
method. That adds noise without clarifying business rules.

## Decision

Create a use case only when the operation:

- contains business rules or validation,
- combines multiple repositories,
- is reused by multiple ViewModels, or
- represents an important business action (login, logout, update profile).

Simple reads may be called from the ViewModel through a repository interface.

## Consequences

- Less boilerplate; meaningful domain operations remain visible.
- ViewModels may call repositories directly for trivial reads — acceptable when
  the dependency is still inverted through an interface.
- Teams must judge “business value” consistently.

## Alternatives considered

- Use case for every method: consistent but noisy.
- No use cases at all: pushes validation and orchestration into ViewModels.
