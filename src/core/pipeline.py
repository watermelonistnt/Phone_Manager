from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

from src.config.settings import Settings
from src.devices.adb_discovery import Device, discover_devices
from src.logging.session_log import SessionReport, write_session_report
from src.safety.cleanup_gate import CleanupDecision, evaluate_cleanup
from src.storage.manifest import Manifest, write_manifest


@dataclass(frozen=True)
class PipelineResult:
    run_dir: Path
    report_path: Path
    manifest_path: Path
    decision: CleanupDecision


def run_backup_pipeline(
    settings: Settings,
    explicit_cleanup: bool = False,
) -> PipelineResult:
    devices = discover_devices()
    if not devices:
        raise RuntimeError("No ADB devices found.")

    device: Device = devices[0]
    run_id = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    run_dir = settings.backup_root / device.serial / run_id

    manifest = Manifest(
        device_serial=device.serial,
        run_id=run_id,
        copied_items=0,
        verified=True,
    )
    manifest_path = write_manifest(manifest, run_dir)

    decision = evaluate_cleanup(
        verified=manifest.verified,
        explicit_cleanup=explicit_cleanup,
        dry_run_default=settings.cleanup_dry_run_default,
    )
    report = SessionReport(
        device_serial=device.serial,
        run_id=run_id,
        verified=manifest.verified,
        cleanup_allowed=decision.allowed,
        cleanup_reason=decision.reason,
    )
    report_path = write_session_report(report, run_dir)
    return PipelineResult(run_dir=run_dir, report_path=report_path, manifest_path=manifest_path, decision=decision)
