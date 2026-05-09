# Agent Workflow

## Objective

Keep work safe, reviewable, and reproducible while iterating with coding agents.

## Policy source of truth

- Read root `AGENT.md` first for global governance.
- Read scoped `AGENT.md` files when working in `docs/`, `src/`, or `tests/`.
- Root policies are mandatory and cannot be overridden by folder guidance.

## Session flow

1. Read root `AGENT.md` and relevant folder `AGENT.md`.
2. Read `docs/progress.md`, root `CURRENT_STATUS.html`, and open items in `docs/decisions/`.
3. Pick one scoped task with clear acceptance criteria.
4. Implement minimal changes with tests.
5. Run `make lint`, `make test`, and repo safety checks.
6. After progress-bearing work or user-stated future jobs: **default** = spawn background **Task** scoped only to `docs/progress.md` + `CURRENT_STATUS.html` (parent does not edit those paths that turn). Fallback or docs-only session → edit both inline.

## Handoff protocol (required)

After each meaningful change, sync handoff:

- **Preferred:** background Task updates only `docs/progress.md` + `CURRENT_STATUS.html` (see root `AGENT.md`).
- **Or** parent updates both when Task unavailable or session is docs-only on those files.
- related ADR in `docs/decisions/` when architecture or policy changes
- root/folder `AGENT.md` when governance rules change

## Progress log policy

- Logging level: balanced.
- Keep concise signal only:
  - meaningful implementation outcome
  - key decision
  - blocker state
  - validation result
  - next action
- Pre-push prune allowed on current session block.
- Post-push blocks are immutable.
- One push should produce one concise finalized log block.

## Firmed ideas on status board

- When an idea is agreed and stable, add one short bullet under **Firmed ideas** in `CURRENT_STATUS.html`.
- Mirror the same decision in `docs/progress.md` (or an ADR if it is architectural).

## Parallel / background updates (default)

- User does not need to repeat the instruction: agent **automatically** starts a background Task for `docs/progress.md` + `CURRENT_STATUS.html` after substantive work or when user raises future jobs.
- Parent avoids editing those paths in the same turn when Task runs.
- Review combined diff before commit.

## Documentation as interface rule

Assume future maintainers may not read source deeply. Document operational intent, constraints, and decision rationale so an agent can continue from docs with minimal ambiguity.

## Previous baseline flow (reference)

1. Read `docs/progress.md` and open items in `docs/decisions/`.
2. Pick one scoped task with clear acceptance criteria.
3. Implement minimal changes with tests.
4. Run `make lint` and `make test`.
5. Handoff via parallel Task (see session flow) or inline fallback.

## Guardrails

- Do not bypass safety checks around cleanup.
- Do not mix unrelated refactors with behavior changes.
- Keep operator-facing messages plain and explicit.
- Do not process or commit personal data files.

## Commit and push governance

- After each meaningful stage, suggest commit and push to preserve progress.
- Before commit/push, run secret-safety checks and review staged changes.
- **Commit-only** messages: no `AUTHOURISE` gate; no mandatory push sentence.
- **Push requests**: summarize changes using `docs/templates/git-push-summary.md`, then ask for approval with exact sentence `say "AUTHOURISE" to push to git`.
- **Last-sentence rule:** If a reply includes `say "AUTHOURISE" to push to git` or `PUSHED to git`, that exact sentence must be the **final sentence** of the assistant message (nothing after it).
- Never push unless the user explicitly replies `AUTHOURISE`.
- After successful push: reply with exact sentence `PUSHED to git` as the **last sentence** of the message.

## PR review checklist

- Architecture boundaries respected.
- Tests cover happy path and failure gate path.
- Cleanup action requires explicit opt-in.
- Manifest verification outcomes are visible in reports.
