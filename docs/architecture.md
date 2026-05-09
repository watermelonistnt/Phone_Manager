# Architecture

## System context

The tool runs on a desktop computer and orchestrates Android backup/cleanup using **MTP** (USB file transfer / Shell namespace on Windows) for operator-driven copies, with the desktop filesystem as the system of record for backup snapshots and manifests. **ADB is not used.**

## Module boundaries

- `src/cli`: command entrypoints and argument parsing
- `src/core`: orchestration pipeline and run state transitions
- `src/collectors`: source-specific export/copy logic (Camera, WhatsApp wrapper)
- `src/storage`: backup snapshot layout, manifest write/read, integrity checks
- `src/safety`: cleanup eligibility checks and dry-run enforcement
- `src/config`: typed settings and path conventions
- `src/logging`: structured run logs and user-facing reports
- `tools/`: desktop helpers (e.g. Windows MTP copy script)

## Primary workflow

1. Identify the logical device id from config (`backup.deviceId`) for snapshot paths.
2. Build backup plan by enabled collectors (future: wired to MTP copy paths).
3. Copy data to timestamped snapshot.
4. Generate manifest with hashes and metadata.
5. Verify copied files against manifest.
6. Gate cleanup based on explicit mode + verification status.
7. Emit session report.

## Safety invariants

- Cleanup is never automatic after backup; it is a separate explicit operation.
- Cleanup defaults to dry-run.
- Deletion is blocked when manifest verification fails or is incomplete.
- Run reports must always include verification and cleanup decision outcomes.

## Storage model

- Root: `data/backups/<device_id>/<run_timestamp>/`
- Manifest: `manifest.json` per run
- Reports: `session_report.json` per run
- Snapshots are immutable after verification success.

## Non-goals for v1

- iOS support
- Real-time syncing
- In-phone app UI
- Cloud storage integrations
