# Architecture

## System context

The tool runs on a desktop computer and orchestrates Android backup/cleanup through ADB. Phones are treated as source devices, while the desktop filesystem is the system of record for backup snapshots and manifests.

## Module boundaries

- `src/cli`: command entrypoints and argument parsing
- `src/core`: orchestration pipeline and run state transitions
- `src/devices`: device discovery and ADB connection validation
- `src/collectors`: source-specific export/copy logic (Camera, WhatsApp wrapper)
- `src/storage`: backup snapshot layout, manifest write/read, integrity checks
- `src/safety`: cleanup eligibility checks and dry-run enforcement
- `src/config`: typed settings and path conventions
- `src/logging`: structured run logs and user-facing reports

## Primary workflow

1. Discover device candidates.
2. Validate ADB connectivity and trust state.
3. Build backup plan by enabled collectors.
4. Copy data to timestamped snapshot.
5. Generate manifest with hashes and metadata.
6. Verify copied files against manifest.
7. Gate cleanup based on explicit mode + verification status.
8. Emit session report.

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
