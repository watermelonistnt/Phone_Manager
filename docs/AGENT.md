# docs/AGENT.md

Read root `AGENT.md` first. This file only adds docs-specific guidance.

## Purpose

Maintain documentation as the primary interface for AI-agent handoff and user visibility.

## Rules

- Keep docs concise, task-oriented, and current.
- Update `docs/progress.md` after meaningful implementation changes.
- Record architecture-level decisions in `docs/decisions/` as ADR updates.
- Do not include secrets, personal data, or local machine identifiers.
- For push approvals, use `docs/templates/git-push-summary.md` and require explicit `AUTHOURISE`.

## Minimum docs updates per feature change

- `docs/progress.md` session entry
- Any affected operational steps in `docs/operations.md`
- Any affected agent workflow notes in `docs/agent-workflow.md`
