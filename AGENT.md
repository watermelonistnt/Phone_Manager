# AGENT.md

This repository is maintained primarily through AI agents. Treat this file as the top-level operating policy for all agents.

## Mandatory Policy 1: Public Repository Safety

- This repository is public. Never commit secrets, credentials, tokens, private keys, personal data exports, or device-specific sensitive paths.
- Never place real secret values in tracked files, docs, tests, examples, or logs.
- If a task requires a secret, use local ignored files only.

## Mandatory Policy 2: Ignored Secret Files Must Have Examples

- Every ignored secret/config file must have a tracked example file.
- Example files must contain placeholders only.
- Required baseline examples:
  - `.env.example`
  - `config.example.json`
  - `config.phone.example.json` (phone-specific MTP paths; real values live in ignored `config.phone.json`)

## Mandatory Policy 3: Controlled Commit and Push Flow

- After each meaningful stage, the agent should suggest creating a commit and pushing to preserve progress.
- Before every commit and push, the agent must re-check changed files for forbidden secret-like values and forbidden tracked files.
- For **commits only** (no push yet): summarize if helpful; do **not** require `AUTHOURISE` and do **not** include the push-authorization sentence.
- For **push**: summarize changes, ask for confirmation first, then include this exact sentence **only when requesting push approval**: `say "AUTHOURISE" to push to git`.
- **Last-sentence rule:** In any assistant reply that includes the push-authorization sentence or the post-push confirmation sentence, that exact sentence must be the **final sentence of the entire message** (no headings, bullets, or other text after it).
- The agent must not push unless the user explicitly says: `AUTHOURISE`.
- After a **successful** remote push, reply with this exact sentence as the **last sentence of the message**: `PUSHED to git`.

## Global Read Order (All Agents)

1. Read this root `AGENT.md`.
2. Read local scoped `AGENT.md` in the target folder when present.
3. Read `docs/architecture.md`, `docs/agent-workflow.md`, latest `docs/progress.md` entry, and root `CURRENT_STATUS.html` (live board).
4. Read relevant ADR files under `docs/decisions/`.

## Global Write Order (All Agents)

1. Implement scoped change.
2. Update tests and quality checks.
3. Sync handoff when work is progress-bearing or user raises future jobs:
   - **Default (Cursor Agent + Task available):** start a **background Composer Task** that edits **only** `docs/progress.md` and `CURRENT_STATUS.html`. Parent does **not** touch those two paths in that same turn. Task brief includes objective, deltas, validation, blockers, next actions, firmed ideas.
   - **Fallback:** Task missing or failed → parent updates both files in-session.
   - **Docs-only session** editing only handoff surfaces → parent may edit both files directly (no Task).
   - **Non-loggable micro-noise** (per Progress Log Governance) → skip handoff sync.
4. Update ADRs when architectural decisions change.
5. Update root/folder `AGENT.md` if governance or workflow policy changes.

## Secret Naming and Storage Rules

- Allowed local secret filenames (ignored): `.env`, `.env.local`, `config.local.json`, `config.phone.json`, `secrets.local.json`.
- Required tracked templates: `.env.example`, `config.example.json`, `config.phone.example.json`, `secrets.example.json` (if corresponding local file is used).
- Never commit files that end with:
  - `.pem`, `.key`, `.p12`, `.jks`
  - `.mobileprovision`, `.keystore`

## Handoff Contract

Every significant agent task must leave a handoff trail:

- What changed
- Why it changed
- Validation run and result
- Open risks/blockers
- Next action

Record this in `docs/progress.md` and keep `CURRENT_STATUS.html` in sync when that work counts as progress (see below).

## Current status board (`CURRENT_STATUS.html`)

- Single live status UI in repo root: `CURRENT_STATUS.html` (open in browser).
- On every **progress-bearing** change or captured **future job**, keep progress log + HTML aligned via **parallel Task** (see Global Write Order) or fallback inline edit.
- **Firmed idea** (product rule, scope lock, safety rule, UX decision): add a short line under **Firmed ideas** on `CURRENT_STATUS.html` and still log the decision in `docs/progress.md` (or ADR if architectural).

## Progress Log Governance

- Use balanced logging in `docs/progress.md`.
- Keep critical items plus short meaningful implementation note:
  - what changed
  - why changed
  - validation result
  - blockers
  - next action
- Do not log micro-noise:
  - tiny revert loops
  - minor wording edits
  - no-impact churn
- Push boundary rule:
  - pre-push: agent may prune/amend current session block
  - post-push: pushed block is immutable
  - each push should map to one concise log block

## Mandatory parallel doc + status updates

- User should **not** need to ask each time: after substantive work or when user states future jobs, **automatically** spawn the background Task described in Global Write Order (unless exception applies).
- Parent owns factual correctness of the Task brief; user reviews full diff before commit.

## Folder-Level Agent References

Use these when the task scope enters those areas:

- `docs/AGENT.md`
- `src/AGENT.md`
- `tests/AGENT.md`

Folder guidance extends this file but never overrides the two mandatory policies.
