from __future__ import annotations

import json
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class Settings:
    backup_root: Path = Path("data/backups")
    logs_root: Path = Path("logs")
    cleanup_dry_run_default: bool = True
    device_id: str = "mtp-device"
    nas_media_root: Path | None = None


def _deep_merge(base: dict[str, Any], overlay: dict[str, Any]) -> dict[str, Any]:
    out = dict(base)
    for key, value in overlay.items():
        if key in out and isinstance(out[key], dict) and isinstance(value, dict):
            out[key] = _deep_merge(out[key], value)
        else:
            out[key] = value
    return out


def _path_or_none(raw: object) -> Path | None:
    if not isinstance(raw, str):
        return None
    stripped = raw.strip()
    return Path(stripped) if stripped else None


def _device_id_from_config(raw: object) -> str | None:
    if not isinstance(raw, str):
        return None
    stripped = raw.strip()
    return stripped or None


def load_settings() -> Settings:
    merged: dict[str, Any] = {}
    for candidate in (Path("config.json"), Path("config.local.json")):
        if candidate.is_file():
            merged = _deep_merge(merged, json.loads(candidate.read_text(encoding="utf-8")))

    backup = merged.get("backup") or {}
    storage = merged.get("storage") or {}
    return replace(
        Settings(),
        device_id=_device_id_from_config(backup.get("deviceId")) or "mtp-device",
        nas_media_root=_path_or_none(storage.get("nasMediaRoot")),
    )
