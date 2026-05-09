from __future__ import annotations

from pathlib import Path

import pytest

from src.config.settings import Settings
from src.core.pipeline import run_backup_pipeline
from src.devices.adb_discovery import Device


def test_pipeline_writes_manifest_and_report(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setattr(
        "src.core.pipeline.discover_devices",
        lambda: [Device(serial="device123", state="device")],
    )
    settings = Settings(backup_root=tmp_path / "backups", logs_root=tmp_path / "logs")

    result = run_backup_pipeline(settings=settings, explicit_cleanup=False)

    assert result.manifest_path.exists()
    assert result.report_path.exists()
    assert result.decision.allowed is False
