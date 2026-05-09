# Agent Workflow

## Objective

Keep work safe, reviewable, and reproducible while iterating with coding agents.

## Session flow

1. Read `docs/progress.md` and open items in `docs/decisions/`.
2. Pick one scoped task with clear acceptance criteria.
3. Implement minimal changes with tests.
4. Run `make lint` and `make test`.
5. Update `docs/progress.md` with outcomes and next actions.

## Guardrails

- Do not bypass safety checks around cleanup.
- Do not mix unrelated refactors with behavior changes.
- Keep operator-facing messages plain and explicit.
- Do not process or commit personal data files.

## PR review checklist

- Architecture boundaries respected.
- Tests cover happy path and failure gate path.
- Cleanup action requires explicit opt-in.
- Manifest verification outcomes are visible in reports.
