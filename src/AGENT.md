# src/AGENT.md

Read root `AGENT.md` first. This file only adds source-code guidance.

## Purpose

Preserve module boundaries and keep implementation understandable for agent-only maintenance.

## Rules

- Keep behavior changes scoped to the correct module boundary.
- Preserve safety invariants around cleanup gating and verification.
- Prefer explicit, typed interfaces over implicit coupling.
- Add or update tests for any behavior changes.

## Module ownership map

- `src/collectors`: source-specific data collection planning and execution
- `src/storage`: snapshot and manifest persistence
- `src/safety`: cleanup eligibility and dry-run enforcement
- `src/core`: orchestration pipeline
- `src/cli`: command interface and operator messaging
