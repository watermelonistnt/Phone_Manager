from __future__ import annotations

from pathlib import Path

import pytest

from src.config.settings import Settings, load_merged_config_dict, load_settings


def test_load_settings_defaults_when_no_config(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.chdir(tmp_path)
    settings = load_settings()
    assert isinstance(settings, Settings)
    assert settings.device_id == "mtp-device"
    assert settings.nas_media_root is None
    assert settings.active_user_id is None
    assert settings.mtp_this_pc_device_name_substring is None


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


def test_nested_active_phone_sets_device_and_mtp(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.chdir(tmp_path)
    (tmp_path / "config.json").write_text(
        '{"activeUserId": "u1", "activePhoneId": "p1", '
        '"users": {"u1": {"phones": {"p1": {'
        '"thisPcDeviceNameSubstring": "GalaxyTest", "backupDeviceId": "snap-id", '
        '"mtp": {"relativePath": "AUTO", "maxSearchDepth": 15}}}}}, '
        '"backup": {"deviceId": "fallback-id"}}',
        encoding="utf-8",
    )
    settings = load_settings()
    assert settings.device_id == "snap-id"
    assert settings.active_user_id == "u1"
    assert settings.active_phone_id == "p1"
    assert settings.mtp_this_pc_device_name_substring == "GalaxyTest"
    assert settings.mtp_relative_path == "AUTO"
    assert settings.mtp_max_search_depth == 15


def test_nested_profile_missing_backup_device_id_uses_top_level(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.chdir(tmp_path)
    (tmp_path / "config.json").write_text(
        '{"activeUserId": "u1", "activePhoneId": "p1", '
        '"users": {"u1": {"phones": {"p1": {'
        '"thisPcDeviceNameSubstring": "PhoneX", "mtp": {"relativePath": ""}}}}}, '
        '"backup": {"deviceId": "top-level-id"}}',
        encoding="utf-8",
    )
    settings = load_settings()
    assert settings.device_id == "top-level-id"
    assert settings.mtp_this_pc_device_name_substring == "PhoneX"


def test_invalid_active_path_falls_back_to_backup_device_id(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.chdir(tmp_path)
    (tmp_path / "config.json").write_text(
        '{"activeUserId": "ghost", "activePhoneId": "missing", '
        '"users": {"u1": {"phones": {}}}, "backup": {"deviceId": "solo"}}',
        encoding="utf-8",
    )
    settings = load_settings()
    assert settings.device_id == "solo"
    assert settings.active_user_id is None


def test_load_merged_config_dict_order(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.chdir(tmp_path)
    (tmp_path / "config.json").write_text('{"a": 1, "nested": {"x": 1}}', encoding="utf-8")
    (tmp_path / "config.local.json").write_text('{"nested": {"y": 2}, "b": 2}', encoding="utf-8")
    (tmp_path / "config.phone.json").write_text('{"a": 3, "nested": {"z": 3}}', encoding="utf-8")
    merged = load_merged_config_dict()
    assert merged["a"] == 3
    assert merged["b"] == 2
    assert merged["nested"]["x"] == 1
    assert merged["nested"]["y"] == 2
    assert merged["nested"]["z"] == 3


def test_nested_camera_relative_path_overrides_relative_path(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.chdir(tmp_path)
    (tmp_path / "config.phone.json").write_text(
        '{"activeUserId": "u1", "activePhoneId": "p1", '
        '"users": {"u1": {"phones": {"p1": {'
        '"thisPcDeviceNameSubstring": "P", "backupDeviceId": "id1", '
        '"mtp": {"relativePath": "AUTO", "cameraRelativePath": "DCIM/Camera", '
        '"whatsappMediaRelativePath": "Android/media/com.whatsapp/WhatsApp/Media"}}}}}}',
        encoding="utf-8",
    )
    settings = load_settings()
    assert settings.mtp_relative_path == "DCIM/Camera"
    assert settings.mtp_whatsapp_media_relative_path == "Android/media/com.whatsapp/WhatsApp/Media"
