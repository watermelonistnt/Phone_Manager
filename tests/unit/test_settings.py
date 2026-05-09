from __future__ import annotations

from pathlib import Path

import pytest

from src.config.settings import Settings, load_settings


def test_load_settings_defaults_when_no_config(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.chdir(tmp_path)
    settings = load_settings()
    assert isinstance(settings, Settings)
    assert settings.device_id == "mtp-device"
    assert settings.nas_media_root is None


def test_load_settings_prefers_local_overlay(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.chdir(tmp_path)
    (tmp_path / "config.json").write_text(
        '{"backup": {"deviceId": "phone-a"}, "storage": {"nasMediaRoot": "D:/nas/share"}}',
        encoding="utf-8",
    )
    (tmp_path / "config.local.json").write_text(
        '{"backup": {"deviceId": "phone-b"}}',
        encoding="utf-8",
    )
    settings = load_settings()
    assert settings.device_id == "phone-b"
    assert settings.nas_media_root == Path("D:/nas/share")
