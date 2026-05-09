# ADR-0004: MTP-first desktop path for Android v1 (no ADB)

## Status

Accepted

## Context

Operators successfully copy camera media over USB using Windows MTP (`Shell.Application`) without Android Platform Tools. ADB added friction (wireless pairing, device authorization) and is not required for the current family backup workflow.

## Decision

Scope v1 Android desktop integration to **MTP / Explorer-equivalent access** on Windows (`tools/mtp_copy.ps1`). Remove ADB from application code and documentation. The Python pipeline uses a configured logical **`backup.deviceId`** for snapshot paths and manifest `device_serial` (legacy field name; value is not an adb serial).

## Consequences

- Simpler operator story on Windows; no `adb` install for MTP-only flows
- Automated collectors must align with MTP-visible paths or future WPD APIs; no `adb pull`
- Supersedes ADR-0001 for connection transport choice (see ADR-0001 status)
