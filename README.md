# Phone Manager (Android First)

Desktop-side Python automation for backing up Android phone data and safely freeing device storage with minimal end-user interaction.

## Why this project exists

This project targets family users who are not comfortable with technical steps on phones and computers. The workflow prioritizes:

- Simple operator flow from one desktop command set
- Safety-first backup verification before any deletion
- Clear progress reporting and rollback-friendly behavior

## V1 scope

- Android phones accessed from the desktop over **USB MTP** on Windows (`tools/mtp_copy.ps1` for file copy smoke tests)
- Python pipeline for manifests, reports, and cleanup gates (`backup.deviceId` in config names snapshot folders)
- Backup focus: Camera media and WhatsApp-exported data (collectors to align with MTP paths over time)
- Manifest-based integrity verification
- Cleanup gate with dry-run default

## Quickstart

1. Install Python 3.12.
2. Run:
   - `make setup`
   - `make lint`
   - `make test`
   - `make run`
3. Optional: copy one camera photo over MTP on Windows — `make mtp-copy-photo` or see `docs/operations.md`.

See `docs/architecture.md` for design details and `docs/operations.md` for runbook steps.
