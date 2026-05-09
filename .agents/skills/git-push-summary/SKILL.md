---
name: git-push-summary
description: Summarize staged and unstaged git changes for push approval, run secret-safety rechecks, and enforce explicit AUTHOURISE confirmation before any push. Use when preparing commits, requesting push confirmation, or handling release stage handoffs.
disable-model-invocation: true
---

# Git Push Summary Skill

## Purpose

Provide a consistent push-approval workflow for this repository:

1. Re-check changes for secret safety.
2. Summarize what changed.
3. Ask for explicit push authorization.

## Required Workflow

1. Inspect current git state (`status`, relevant diffs, recent commits).
2. Run repository safety checks before commit/push.
3. Summarize changes using the template at `docs/templates/git-push-summary.md`.
4. When **requesting push** (not for commit-only updates): ask for approval and include the exact sentence `say "AUTHOURISE" to push to git` as the **last sentence** of the assistant message (no text after it).
5. Push only after the user replies with `AUTHOURISE`.
6. After push succeeds, reply with exact sentence `PUSHED to git` as the **last sentence** of the assistant message (no text after it).

## Hard Rules

- Never push before explicit `AUTHOURISE`.
- If either magic sentence appears in a reply, it must be the **final sentence** of that entire message.
- If safety check fails, do not push. Report failure and suggest fixes.
- Keep summary focused on behavior, risk, and validation results.

## Summary Template Source

- Use and adapt: `docs/templates/git-push-summary.md`
