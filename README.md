# Phone Manager (Android First)

Desktop-side Python automation for backing up Android phone data and safely freeing device storage with minimal end-user interaction.

## Why this project exists

This project targets family users who are not comfortable with technical steps on phones and computers. The workflow prioritizes:

- Simple operator flow from one desktop command set
- Safety-first backup verification before any deletion
- Clear progress reporting and rollback-friendly behavior

## V1 scope

- Android devices connected through ADB
- Backup focus: Camera media and WhatsApp-exported data
- Manifest-based integrity verification
- Cleanup gate with dry-run default

## Quickstart

1. Install Python 3.12.
2. Install Android Platform Tools (`adb`) and confirm `adb version`.
3. Run:
   - `make setup`
   - `make lint`
   - `make test`
   - `make run`

See `docs/architecture.md` for design details and `docs/operations.md` for runbook steps.
