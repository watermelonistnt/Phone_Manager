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
    active_user_id: str | None = None
    active_phone_id: str | None = None
    mtp_this_pc_device_name_substring: str | None = None
    mtp_relative_path: str = ""
    mtp_max_search_depth: int = 20
    mtp_whatsapp_media_relative_path: str | None = None


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


def _str_or_empty(raw: object) -> str:
    if not isinstance(raw, str):
        return ""
    return raw.strip()


def _resolve_active_phone_profile(merged: dict[str, Any]) -> dict[str, Any] | None:
    """Return normalized active phone dict or None if actives/users/phones path is missing."""
    uid_raw = merged.get("activeUserId")
    pid_raw = merged.get("activePhoneId")
    if not isinstance(uid_raw, str) or not uid_raw.strip():
        return None
    if not isinstance(pid_raw, str) or not pid_raw.strip():
        return None
    uid, pid = uid_raw.strip(), pid_raw.strip()
    users = merged.get("users")
    if not isinstance(users, dict):
        return None
    user = users.get(uid)
    if not isinstance(user, dict):
        return None
    phones = user.get("phones")
    if not isinstance(phones, dict):
        return None
    phone = phones.get(pid)
    if not isinstance(phone, dict):
        return None

    mtp_raw = phone.get("mtp")
    mtp: dict[str, Any] = mtp_raw if isinstance(mtp_raw, dict) else {}

    cam_raw = mtp.get("cameraRelativePath")
    rel_raw = mtp.get("relativePath")
    if isinstance(cam_raw, str) and cam_raw.strip():
        mtp_camera = cam_raw.strip()
    elif isinstance(rel_raw, str):
        mtp_camera = rel_raw.strip()
    else:
        mtp_camera = ""

    depth_raw = mtp.get("maxSearchDepth", 20)
    try:
        mtp_depth = int(depth_raw)
    except (TypeError, ValueError):
        mtp_depth = 20
    if mtp_depth < 1:
        mtp_depth = 20

    name_raw = phone.get("thisPcDeviceNameSubstring")
    name_s = name_raw.strip() if isinstance(name_raw, str) else ""

    bid_raw = phone.get("backupDeviceId")
    bid_s = bid_raw.strip() if isinstance(bid_raw, str) else ""

    wa_raw = mtp.get("whatsappMediaRelativePath")
    wa_s = wa_raw.strip() if isinstance(wa_raw, str) else ""

    return {
        "thisPcDeviceNameSubstring": name_s,
        "backupDeviceId": bid_s,
        "mtpRelativePath": mtp_camera,
        "mtpMaxSearchDepth": mtp_depth,
        "mtpWhatsappMediaRelativePath": wa_s or None,
    }


def load_merged_config_dict() -> dict[str, Any]:
    """Merge ``config.json``, ``config.local.json``, then ``config.phone.json`` (later wins)."""
    merged: dict[str, Any] = {}
    for candidate in (Path("config.json"), Path("config.local.json"), Path("config.phone.json")):
        if candidate.is_file():
            merged = _deep_merge(merged, json.loads(candidate.read_text(encoding="utf-8")))
    return merged


def load_settings() -> Settings:
    merged = load_merged_config_dict()

    backup = merged.get("backup") or {}
    storage = merged.get("storage") or {}
    profile = _resolve_active_phone_profile(merged)

    active_user_id: str | None = None
    active_phone_id: str | None = None
    mtp_name: str | None = None
    mtp_rel = ""
    mtp_depth = 20
    mtp_wa: str | None = None
    device_id: str

    if profile is not None:
        uid_r = merged.get("activeUserId")
        pid_r = merged.get("activePhoneId")
        active_user_id = uid_r.strip() if isinstance(uid_r, str) else None
        active_phone_id = pid_r.strip() if isinstance(pid_r, str) else None
        bid = profile.get("backupDeviceId", "")
        device_id = (
            _device_id_from_config(bid)
            or _device_id_from_config(backup.get("deviceId"))
            or "mtp-device"
        )
        sub = profile.get("thisPcDeviceNameSubstring", "")
        mtp_name = sub if isinstance(sub, str) and sub.strip() else None
        rel_raw = profile.get("mtpRelativePath")
        mtp_rel = rel_raw if isinstance(rel_raw, str) else ""
        mtp_depth = int(profile.get("mtpMaxSearchDepth", 20))
        wa = profile.get("mtpWhatsappMediaRelativePath")
        mtp_wa = wa if isinstance(wa, str) and wa.strip() else None
    else:
        device_id = _device_id_from_config(backup.get("deviceId")) or "mtp-device"

    return replace(
        Settings(),
        device_id=device_id,
        nas_media_root=_path_or_none(storage.get("nasMediaRoot")),
        active_user_id=active_user_id,
        active_phone_id=active_phone_id,
        mtp_this_pc_device_name_substring=mtp_name,
        mtp_relative_path=mtp_rel,
        mtp_max_search_depth=mtp_depth,
        mtp_whatsapp_media_relative_path=mtp_wa,
    )
