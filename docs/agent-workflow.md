# Agent Workflow

## Objective

Keep work safe, reviewable, and reproducible while iterating with coding agents.

## Policy source of truth

- Read root `AGENT.md` first for global governance.
- Read scoped `AGENT.md` files when working in `docs/`, `src/`, or `tests/`.
- Root policies are mandatory and cannot be overridden by folder guidance.

## Session flow

1. Read root `AGENT.md` and relevant folder `AGENT.md`.
2. Read `docs/progress.md` and open items in `docs/decisions/`.
3. Pick one scoped task with clear acceptance criteria.
4. Implement minimal changes with tests.
5. Run `make lint`, `make test`, and repo safety checks.
6. Update `docs/progress.md` with outcomes and next actions.

## Handoff protocol (required)

After each meaningful change, update:

- `docs/progress.md` with change summary, validation, blockers, and next steps
- related ADR in `docs/decisions/` when architecture or policy changes
- root/folder `AGENT.md` when governance rules change

## Documentation as interface rule

Assume future maintainers may not read source deeply. Document operational intent, constraints, and decision rationale so an agent can continue from docs with minimal ambiguity.

## Previous baseline flow (reference)

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

## Commit and push governance

- After each meaningful stage, suggest commit and push to preserve progress.
- Before commit/push, run secret-safety checks and review staged changes.
- For every push request, summarize changes using `docs/templates/git-push-summary.md`.
- Never push unless the user explicitly replies `AUTHOURISE`.
- Every push request must include: `say "AUTHOURISE" to push to git`.

## PR review checklist

- Architecture boundaries respected.
- Tests cover happy path and failure gate path.
- Cleanup action requires explicit opt-in.
- Manifest verification outcomes are visible in reports.
