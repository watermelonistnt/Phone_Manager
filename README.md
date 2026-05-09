# Phone Manager (Android First)

Desktop-side Python automation for backing up Android phone data and safely freeing device storage with minimal end-user interaction.

## Why this project exists

This project targets family users who are not comfortable with technical steps on phones and computers. The workflow prioritizes:

- Simple operator flow from one desktop command set
- Safety-first backup verification before any deletion
- Clear progress reporting and rollback-friendly behavior

## V1 scope

- Android phones accessed from the desktop over **USB MTP** on Windows (`tools/mtp_copy.ps1` for file copy smoke tests)
- Python pipeline for manifests, reports, and cleanup gates (`backup.deviceId` or nested **`users.*.phones.*.backupDeviceId`** names snapshot folders; see `docs/operations.md`)
- Backup focus: Camera media and WhatsApp-exported data (collectors to align with MTP paths over time)
- Manifest-based integrity verification
- Cleanup gate with dry-run default

## Quickstart

1. Install Python 3.12.
2. From the repo root, run (GNU **Make** optional — if `make` is missing on Windows, use the **Python** lines instead):
   - `make setup` — or: `py -3.12 -m venv .venv` then `.venv\Scripts\python -m pip install -e ".[dev]"` (PowerShell).
   - `make lint` — or: `.venv\Scripts\python -m ruff check .` then `black --check .` then `mypy src`.
   - `make test` — or: `.venv\Scripts\python -m pytest`.
   - `make run` — or: `.venv\Scripts\python -m src.cli.main run` (or `py -3.12 -m src.cli.main run` if the package is on `PYTHONPATH` / installed editable).
3. Optional: phone MTP paths — from repo root run **`py -3.12 -m src.cli.main phone-init`** (or **`python -m src.cli.main phone-init`**) once to create ignored **`config.phone.json`** from **`config.phone.example.json`**; with Make installed, `make phone-config` does the same. Then edit that file (see `docs/operations.md`). There is no standalone `phone-init` executable on `PATH`.
4. Optional: copy one camera photo over MTP on Windows — `make mtp-copy-photo` **or** the PowerShell one-liner in `docs/operations.md` (merged `config.json` + **`config.local.json`** + **`config.phone.json`** when using **`-UseRepoConfig`**). For per-file archive to NAS with phone quarantine, see **`make mtp-archive-list`** / **`make mtp-archive-one`** and **`docs/operations.md`**.

See `docs/architecture.md` for design details and `docs/operations.md` for runbook steps.
