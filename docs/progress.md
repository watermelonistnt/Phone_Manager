# Progress Log

Use this format for meaningful sessions only. Keep balanced signal. Keep pushed blocks immutable.

## 2026-05-09 - MTP AUTO BFS prune (efficiency)

- Objective: AUTO `DCIM/Camera` search skip expanding obviously unrelated / huge subtrees (Android, Music, …); opt-out + repo overrides.
- Completed: `tools/mtp_copy.ps1` default prune list, `-NoDcimBfsPrune`, `mtp.dcimBfsPrune` / `mtp.dcimBfsExtraPruneFolderNames` from merged profile; `config.phone.example.json`; `docs/operations.md`.
- Validation: not run (PowerShell script change).
- Next: none

## 2026-05-09 - MTP WhatsApp path probe (`mtp_copy.ps1`)

- Objective: After camera resolution, resolve **`mtp.whatsappMediaRelativePath`** via same **`Resolve-DeviceSubfolder`** rules; print top-level probe (not recursive).
- Completed: `Show-WhatsAppMediaFolderProbe` + `$script:WhatsappMediaRelativePathFromConfig` from merged profile; `.SYNOPSIS`; `docs/operations.md`.
- Next: optional recursive listing / copy from WhatsApp when product wants it

## 2026-05-09 - DCIM AUTO priority BFS (`mtp_copy.ps1`)

- Objective: Priority search for upcoming phones using **`mtp.dcimBfsPrioritySegments`** + segments from confirmed **`cameraRelativePath`** / **`relativePath`** (not WhatsApp path); prune still wins.
- Completed: two-queue `Find-DcimCameraFolder`, `Build-DcimBfsPrioritySegmentHintsList`, profile + `UseRepoConfig` wiring; `config.phone.example.json`; `docs/operations.md`.
- Next: none

## 2026-05-09 - Push UX: AUTHOURISE / PUSHED last sentence only

- Objective: When an assistant uses the push-request line or post-push confirm line, that exact sentence must be the **final sentence** of the whole message (no trailing content).
- Completed: `AGENT.md` Mandatory Policy 3; `docs/agent-workflow.md`; `docs/AGENT.md`; `docs/templates/git-push-summary.md`; `.cursor/rules/agent-core-policy.mdc`; `.cursor/rules/agent-docs-guidance.mdc`; `.agents/skills/git-push-summary/SKILL.md`; `CURRENT_STATUS.html` (Firmed Ideas).
- Validation: doc cross-read
- Blockers: none
- Next: none

## 2026-05-09 - config.phone.json (gitignored phone paths)

- Objective: Per-phone MTP strings + nested `users`/`phones` off main example into last-merge gitignored layer; bootstrap path for operators.
- Completed:
  - `config.phone.json` gitignored; tracked `config.phone.example.json` placeholders (`activeUserId`, `activePhoneId`, nested `users`/`phones`, `mtp.relativePath`, `mtp.cameraRelativePath`, `mtp.whatsappMediaRelativePath`, `mtp.maxSearchDepth`, `thisPcDeviceNameSubstring`, `backupDeviceId`)
  - `config.example.json` trimmed — top-level backup/storage/notifications only (no nested users in main example)
  - Merge order `config.json` → `config.local.json` → `config.phone.json` in `load_merged_config_dict`; `Settings.mtp_whatsapp_media_relative_path`; camera path prefers `cameraRelativePath`, else `relativePath`
  - `src/config/phone_config.py`; CLI `phone-init`; `make phone-config`; `.gitignore` + `check_repo_safety` requires example, forbids tracking `config.phone.json`
  - `AGENT.md` phone example + ignored file; `mtp_copy.ps1` merged profile paths; `docs/operations.md`, `README.md`; `collectors/whatsapp.py` `build_whatsapp_plan(settings)` uses `mtp_whatsapp_media_relative_path` when set
  - **Micro (same day):** Win ops confused — no `make` on box; `phone-init` not a PATH command (no shim). From repo root use `py -3.12 -m src.cli.main phone-init` or venv `python -m src.cli.main phone-init`. README + `docs/operations.md` now say so.
- Validation: `py -3.12 -m pytest tests -q` → **10** passed; `ruff check src tools tests` OK; `mypy src` OK
- Blockers: none
- Next: wire collectors deeper; optional NAS

## 2026-05-09 - Nested User → Phone config (local + MTP)

- Objective: Maintainer sets `users.{userId}.phones.{phoneKey}` once; family uses `make mtp-copy-photo` / pipeline with `activeUserId` + `activePhoneId`; real This PC strings only in ignored `config.local.json`.
- Completed:
  - `config.example.json` — `activeUserId`, `activePhoneId`, `users`/`phones`, `thisPcDeviceNameSubstring`, `backupDeviceId`, `mtp` block
  - `src/config/settings.py` — `load_merged_config_dict`, `_resolve_active_phone_profile`, Settings fields (`active_user_id`, `active_phone_id`, `mtp_*`), fallback to `backup.deviceId`
  - `tools/read_merged_config.py` + `tools/mtp_copy.ps1` **`-UseRepoConfig`** (Python merge + PSBoundParameters precedence)
  - `Makefile` `mtp-copy-photo` always `-UseRepoConfig`, optional `DEVICE=` override
  - `docs/operations.md` (Per-user phones + MTP UseRepoConfig), `README.md`
  - `tests/unit/test_settings.py` expanded; `py -3.12 -m pytest tests -q` → **9** passed
- Blockers: none
- Next: optional per-phone `nasMediaRoot`; collectors read `Settings` MTP hints
- Layout superseded same day for phone strings: nested profiles + MTP-relative fields default to gitignored `config.phone.json` (template `config.phone.example.json`; merge last — see preceding block).

## 2026-05-09 - Remove ADB; MTP-first v1

- Objective: Drop Android Platform Tools / adb from product plan and Python codebase; align with confirmed MTP copy success.
- Completed:
  - Deleted `src/devices/adb_discovery.py`, removed `src/devices/` package; deleted `tests/unit/test_adb_discovery.py`
  - `src/cli/main.py`: only `run` subcommand (no `devices` list/connect/peek)
  - `src/core/pipeline.py`: `backup.deviceId` via Settings → snapshot path + manifest `device_serial` (logical id)
  - `src/config/settings.py`: removed deviceDiscovery fields; `device_id` + `nas_media_root`; `pyproject.toml` mypy `explicit_package_bases = true` (fixes duplicate-module check)
  - `config.example.json`: `backup.deviceId`; removed deviceDiscovery block
  - Docs: `docs/architecture.md`, `docs/operations.md`, `docs/environment.md`, `README.md`; `src/AGENT.md`; `.cursor/rules/agent-src-guidance.mdc` (no devices module); `tests/integration/test_backup_flow.py` comment
  - ADR: `ADR-0001` status **Superseded**; new **`docs/decisions/ADR-0004-mtp-desktop-v1.md`** Accepted
  - `tools/mtp_copy.ps1`: ASCII hyphen in ListOnly message (encoding)
- Validation: `py -3.12 -m pytest tests -q` → **5** passed; `ruff check src tests`; `mypy src` OK
- Blockers: none
- Next: wire collectors to MTP paths; optional NAS copy from `storage.nasMediaRoot`

## 2026-05-09 - MTP Shell folder reliability (`mtp_copy.ps1`, ops)

- Objective: make MTP navigation robust when **Shell `IsFolder`** on MTP items is **unreliable**, and tighten child-folder resolution / internal-root discovery.
- Completed:
  - **`tools/mtp_copy.ps1`** — **`Test-ShellItemIsFolder`** prefers **`GetFolder()`** (folder probe) over trusting **`IsFolder`** alone; **`Resolve-ShellChildFolder`** **trim** + **`OrdinalIgnoreCase`** name match; **`Find-InternalStorageRoot`** **sole navigable child** fallback when the labeled internal root is unclear
  - **`docs/operations.md`** — MTP **step 4** wording aligned with the above
- Validation:
  - operator-facing; COM / MTP Shell behavior
- Blockers:
  - none
- Next actions:
  - optional: handset smoke where MTP mis-reports folders or exposes a single obvious storage child

## 2026-05-09 - MTP copy default AUTO + BFS `DCIM/Camera` (`mtp_copy.ps1`, ops, README)

- Objective: default **AUTO** source under internal storage — breadth-first search for **`**/DCIM/Camera`** without assuming a single fixed folder layout; cap depth via **`-MaxSearchDepth`**; keep explicit **`-RelativePath`** behavior unchanged for operators who pin a path.
- Completed:
  - **`tools/mtp_copy.ps1`** — **`Find-DcimCameraFolder`** (BFS under resolved internal root); default mode **AUTO**; **`-MaxSearchDepth`** knob
  - **`docs/operations.md`** — MTP line aligned with AUTO discovery + depth limit
  - **`README.md`** — MTP pointer line aligned with script defaults / discovery
- Validation:
  - operator-facing; **`-RelativePath`** explicit path still honored when set
- Blockers:
  - none
- Next actions:
  - optional: handset smoke where `DCIM/Camera` is nested or renamed variants appear only under depth cap edge cases

## 2026-05-09 - MTP internal root locale + DCIM fallback (`mtp_copy.ps1`, ops)

- Objective: when the phone’s MTP root label is not English, still resolve **internal storage** and reach **`DCIM\Camera`**; document localized UI for operators.
- Completed:
  - **`tools/mtp_copy.ps1`** — **internal root locale aliases** (e.g. `內部儲存裝置` when the script default starts from English **`Internal storage`**); after resolving internal, **fallback navigate** **`DCIM\Camera`** under that root
  - **`docs/operations.md`** — **step 6** notes for **localized** MTP / folder UI strings
- Validation:
  - operator-facing only; optional **ListOnly** smoke unchanged intent
- Blockers:
  - none
- Next actions:
  - optional: confirm on a handset whose internal root shows a non-English label

## 2026-05-09 - MTP no-ADB path (`mtp_copy.ps1`, ops, README, Make)

- Objective: give operators a Windows **MTP** path when **ADB** is not available — copy via **`Shell.Application`**, default phone folder **`Internal storage\DCIM\Camera`** → repo **`tmp/mtp-incoming`**; document in ops; one **README** line; **Makefile** target **`mtp-copy-photo`**.
- Completed:
  - **`tools/mtp_copy.ps1`** — COM folder browse/copy; default relative source above; destination under **`tmp/mtp-incoming`**
  - **`docs/operations.md`** — section for MTP / no-ADB workflow (aligned with script usage)
  - **`README.md`** — short pointer to MTP copy + Make target
  - **`Makefile`** — **`mtp-copy-photo`** invokes the script (operator-friendly entry)
- Validation:
  - PowerShell script runs through **device resolution** with **ListOnly** (no full copy required for smoke)
  - **`py -3.12 -m pytest tests -q`** — unchanged vs prior baseline if run (optional check; not gating this path)
- Blockers:
  - none
- Next actions:
  - optional: full copy smoke on a real handset when MTP mode is used in anger

## 2026-05-09 - USB-first ops + non-fixed phone policy + `devices peek` CLI

- Objective: treat USB as the default operator path, document that the managed phone is not tied to a single fixed serial, add a read-only `devices peek` path (remote listing helpers), and align example config with optional serial.
- Completed:
  - operational stance: **USB-first**; **non-fixed phone** — no assumption one serial always maps to the same physical handset unless operator pins it
  - CLI **`devices peek`** using **`peek_remote_listing`** and **`resolve_adb`** (discovery/resolution path for peek)
  - **`config.example.json`** — **`preferredSerial`** set to **`null`** (placeholder = no pin; use `config.local.json` when pinning)
  - **`docs/operations.md`** — sections for **USB**, **swap** (switching handsets / serial), and **peek** (inspect remote listing without implying a fixed device)
- Validation:
  - `py -3.12 -m pytest tests -q` — **21** passed
- Blockers:
  - none
- Next actions:
  - keep ops + CLI in sync when collector or manifest paths gain more device context

## 2026-05-09 - Wi-Fi ADB operator help (ping vs empty `adb devices`)

- Objective: help operators when the phone answers ping but `adb devices` stays empty — pair port vs wireless debugging port, firewall, and quick port checks.
- Completed:
  - `docs/operations.md` — subsection **Ping works but adb devices is empty** (pair vs debug port, firewall, `Test-NetConnection`)
  - CLI `devices connect HOST:PORT` wraps `adb connect`
  - `run_adb_connect` in `src/devices/adb_discovery.py`
- Validation:
  - `py -3.12 -m pytest tests -q` — **19** passed
- Blockers:
  - none
- Next actions:
  - none noted (ops + connect path only)

## 2026-05-09 - Zero transports operator UX (ADB hint + ops)

- Objective: improve operator UX when `adb` lists zero transports — clearer `RuntimeError` path for USB vs Wi‑Fi wireless debugging (`adb pair`, `adb connect`) and a dedicated ops subsection.
- Completed:
  - expanded empty/zero-transport `RuntimeError` hint (USB cable/authorize vs wireless pair/connect)
  - `docs/operations.md` — **No devices in adb**
- Validation:
  - targeted adb/pipeline tests pass
- Blockers:
  - none
- Next actions:
  - none (tiny UX/docs follow-up)

## 2026-05-09 - Confidential device list export + config merge + NAS path placeholder

- Objective: write discovered authorized devices to a private JSON list; load optional paths from merged `config.json` + `config.local.json`; record intended NAS media root for future collectors without committing LAN specifics.
- Completed:
  - `load_settings` deep-merge; Settings fields `device_discovery_list_path`, `nas_media_root`, `preferred_device_serial`
  - `write_confidential_device_list` + `pick_device` in `adb_discovery`; pipeline writes list when path set
  - CLI `devices list` with `--output` (no serials on stdout)
  - `config.example.json` keys; `docs/operations.md` privacy/LAN notes
  - tests — `py -3.12 -m pytest tests` passes (17 tests)
- Decisions:
  - real IPs/hostnames only in ignored `config.local.json`; tracked examples use placeholders
  - default confidential path pattern `data/private/...` under ignored `data/`
- Validation:
  - pytest green (17 tests)
- Blockers:
  - `nas_media_root` not yet consumed by collectors (stub for layout)
- Next actions:
  - wire collectors/snapshot copy toward NAS path when manifest supports it

## 2026-05-09 - Hardened real ADB probing

- Objective: ship hardened real ADB probing (PATH check, `adb devices -l`, authorized-only selection, clear errors).
- Completed:
  - `src/devices/adb_discovery.py` (parse helper + probe behavior)
  - `tests/unit/test_adb_discovery.py`
  - pipeline no longer double-checks empty device list
  - `docs/operations.md` steps for adb PATH and `device` state
- Decisions:
  - only transports with state `device` are used; blocked transports listed in error text
- Validation:
  - `py -3.12 -m pytest tests -q` — all tests pass (9 unit tests including adb + pipeline at time of run)
- Blockers:
  - existing `.venv` may still be Python 3.9 (`pip install -e` fails); recommend `make setup` after recreating venv with 3.12
  - repo-wide `mypy src` may report pre-existing duplicate-module issue — do not claim fixed unless you verified
- Next actions:
  - implement collector adapters + integration fixtures
  - operator: recreate venv with Python 3.12, install `gh`/GitHub auth per board

## 2026-05-09 - Push phrase scope + post-push confirmation

- Objective: use push-auth sentence only when requesting push; confirm after successful push.
- Completed:
  - updated root `AGENT.md` Policy 3, `agent-core-policy.mdc`, `docs/agent-workflow.md`
  - updated `docs/templates/git-push-summary.md`, `.agents/skills/git-push-summary/SKILL.md`
  - updated `docs/AGENT.md`, `agent-docs-guidance.mdc`
  - amended post-push line → `PUSHED to git` (avoid AUTHOURISE-shaped caps on confirm stage)
- Decisions:
  - `say "AUTHOURISE" to push to git` only when asking user to authorize **push** (not commit-only / generic git)
  - after remote push succeeds → agent reply exact line `PUSHED to git`
- Validation:
  - grep sweep for stale wording on touched files
- Blockers:
  - none
- Next actions:
  - follow new phrasing on next push flow

## 2026-05-09 - Mandatory parallel Task for progress + HTML

- Objective: operator never repeats request; auto background Task syncs handoff after substantive work or future-job capture.
- Completed:
  - wrote `.cursor/rules/agent-docs-sync-parallel.mdc` (alwaysApply)
  - updated root `AGENT.md` Global Write Order + mandatory parallel section
  - updated `docs/agent-workflow.md`, `docs/AGENT.md`, `agent-core-policy.mdc`, `agent-docs-guidance.mdc`
  - refreshed pins / Firmed Ideas / How-to on `CURRENT_STATUS.html`
- Decisions:
  - default: Cursor Task scoped **only** `docs/progress.md` + `CURRENT_STATUS.html`; parent skips those paths same turn when Task runs
  - fallback: Task missing/fail → parent edits both
  - docs-only session on those files → parent inline OK
  - micro-noise → no sync
- Validation:
  - policy cross-ref scan OK
- Blockers:
  - none
- Next actions:
  - obey parallel Task on next progress-bearing agent session

## 2026-05-09 - Progress + HTML status sync policy

- Objective: dual-update rule for progress; HTML-only board; firmed ideas on board.
- Completed:
  - wrote rules in root `AGENT.md`, `docs/agent-workflow.md`, `docs/AGENT.md`, `.cursor/rules` for sync
  - removed root `CURRENT_STATUS.md`; extended `CURRENT_STATUS.html` with Firmed Ideas + pin text
  - documented optional Cursor background Task for doc/status updates during code chats
- Decisions:
  - progress-bearing change => touch both `docs/progress.md` and `CURRENT_STATUS.html`
  - firmed idea => bullet under Firmed Ideas on `CURRENT_STATUS.html` + log in progress (or ADR if architecture)
  - markdown status board retired
- Validation:
  - policy files + HTML updated; lint check on touched paths
- Blockers:
  - none
- Next actions:
  - follow dual-update rule on future sessions

## 2026-05-09 - Root live status board

- Objective: one live status doc for pending work, target, next step.
- Completed:
  - made root `CURRENT_STATUS.md`
  - pinned frequent-update rule
  - added `Pending Works`, `Further Target`, `Current Jobs (Next Step)`
  - added update steps + last-updated block
- Decisions:
  - `CURRENT_STATUS.md` = daily status source
  - `docs/progress.md` = session history
- Validation:
  - doc structure check passed
- Blockers:
  - none
- Next actions:
  - update `CURRENT_STATUS.md` end of each meaningful session

## 2026-05-09 - HTML status board view

- Objective: visual board with clear blocks + keyword highlight.
- Completed:
  - made root `CURRENT_STATUS.html` with card layout
  - added chips + highlight style for fast scan
  - kept update protocol + metadata block
- Decisions:
  - `CURRENT_STATUS.html` = visual quick-read board
  - `CURRENT_STATUS.md` stays as plain-text ref
- Validation:
  - visual section/content parity check passed
- Blockers:
  - none
- Next actions:
  - keep `CURRENT_STATUS.html` and `CURRENT_STATUS.md` aligned

## 2026-05-09 - Push authorization governance

- Objective: enforce strict push gate + standard push summary.
- Completed:
  - added push policy to `AGENT.md`
  - added `.agents/skills/git-push-summary/SKILL.md`
  - added `docs/templates/git-push-summary.md`
  - aligned `docs/agent-workflow.md` with explicit `AUTHOURISE` gate
- Decisions:
  - no push before explicit `AUTHOURISE`
  - every push request includes `say "AUTHOURISE" to push to git`
- Validation:
  - policy/docs consistency check passed
- Blockers:
  - none
- Next actions:
  - use summary template on next push request

## 2026-05-09 - Public-safe agent governance

- Objective: enforce public-safe repo rules + agent workflow baseline.
- Completed:
  - made root `AGENT.md` with mandatory safety rules
  - added `.env.example`, `config.example.json`, `secrets.example.json`
  - added scoped `AGENT.md` for `docs/`, `src/`, `tests/`
  - aligned `docs/agent-workflow.md` read/write/handoff flow
- Decisions:
  - root `AGENT.md` is governance source
  - scoped `AGENT.md` adds rules, cannot override root
- Validation:
  - policy coverage review passed
- Blockers:
  - none
- Next actions:
  - add automated safety checks in local + CI

## 2026-05-09 - Project foundation

- Objective: set architecture + AGENT-ready baseline.
- Completed:
  - built repo skeleton + core docs
  - defined Android-first module layout
  - defined toolchain + CI baseline
- Decisions:
  - v1 scope: Android + ADB
  - cleanup blocked if verification not successful
- Validation:
  - baseline docs check passed
- Blockers:
  - `gh` CLI missing in current env
  - Python 3.12 missing (`py` reports 3.9.6)
  - GitHub auth not configured (HTTPS token or SSH key)
- Next actions:
  - implement real ADB probing
  - implement collector adapters + integration fixtures
