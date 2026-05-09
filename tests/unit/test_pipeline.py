from __future__ import annotations

from pathlib import Path

from src.config.settings import Settings
from src.core.pipeline import run_backup_pipeline


def test_pipeline_writes_manifest_and_report(tmp_path: Path) -> None:
    settings = Settings(
        backup_root=tmp_path / "backups",
        logs_root=tmp_path / "logs",
        device_id="device123",
    )

    result = run_backup_pipeline(settings=settings, explicit_cleanup=False)

    assert result.manifest_path.exists()
    assert result.report_path.exists()
    assert result.decision.allowed is False
    assert "device123" in str(result.run_dir)


def test_pipeline_default_device_id(tmp_path: Path) -> None:
    settings = Settings(backup_root=tmp_path / "backups", logs_root=tmp_path / "logs")

    result = run_backup_pipeline(settings=settings, explicit_cleanup=False)

    assert "mtp-device" in str(result.run_dir)
