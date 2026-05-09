# ADR-0001: Android + ADB only for v1

## Status

Accepted

## Context

The first release must reduce delivery risk and ship fast for a family-use scenario.

## Decision

Scope v1 to Android backup and cleanup through ADB only.

## Consequences

- Faster implementation and testability
- Fewer unknowns in device connection logic
- iOS support deferred to a later architecture extension
