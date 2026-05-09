# tests/AGENT.md

Read root `AGENT.md` first. This file only adds testing guidance.

## Purpose

Ensure agent-generated changes remain safe, verifiable, and regression-resistant.

## Rules

- Add unit tests for deterministic logic changes.
- Add integration tests for multi-module workflow changes.
- Prefer fixtures/mocks over real secrets or personal data.
- Keep tests readable so future agents can extend them quickly.

## Minimum coverage intent

- Happy-path pipeline behavior
- Verification/cleanup gate failures
- CLI command contract expectations
