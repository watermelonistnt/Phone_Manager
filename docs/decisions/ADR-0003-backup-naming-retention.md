# ADR-0003: Backup naming and retention policy

## Status

Accepted

## Context

Operators need predictable backup locations and simple retention cleanup.

## Decision

- Backup path format: `data/backups/<device_id>/<YYYYMMDDTHHMMSSZ>/`
- Keep newest snapshots by policy, never mutate verified snapshots.
- Retention cleanup is a future explicit command.

## Consequences

- Easy manual inspection and support
- Deterministic pathing for logs and reports
- Future retention command can be built safely on top
