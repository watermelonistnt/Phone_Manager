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

## Mandatory Policy 3: Controlled Commit and Push Flow

- After each meaningful stage, the agent should suggest creating a commit and pushing to preserve progress.
- Before every commit and push, the agent must re-check changed files for forbidden secret-like values and forbidden tracked files.
- For every push request, the agent must summarize changes and ask for user confirmation first.
- The agent must not push unless the user explicitly says: `AUTHOURISE`.
- Every push request must include this exact sentence: `say "AUTHOURISE" to push to git`.

## Global Read Order (All Agents)

1. Read this root `AGENT.md`.
2. Read local scoped `AGENT.md` in the target folder when present.
3. Read `docs/architecture.md`, `docs/agent-workflow.md`, and latest `docs/progress.md` entry.
4. Read relevant ADR files under `docs/decisions/`.

## Global Write Order (All Agents)

1. Implement scoped change.
2. Update tests and quality checks.
3. Update `docs/progress.md` with outcomes and blockers.
4. Update ADRs when architectural decisions change.
5. Update root/folder `AGENT.md` if governance or workflow policy changes.

## Secret Naming and Storage Rules

- Allowed local secret filenames (ignored): `.env`, `.env.local`, `config.local.json`, `secrets.local.json`.
- Required tracked templates: `.env.example`, `config.example.json`, `secrets.example.json` (if corresponding local file is used).
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

Record this in `docs/progress.md`.

## Folder-Level Agent References

Use these when the task scope enters those areas:

- `docs/AGENT.md`
- `src/AGENT.md`
- `tests/AGENT.md`

Folder guidance extends this file but never overrides the two mandatory policies.
