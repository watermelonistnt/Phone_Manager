from __future__ import annotations

from dataclasses import dataclass

from src.config.settings import Settings


@dataclass(frozen=True)
class WhatsAppCollectorPlan:
    source_path: str = "/sdcard/Android/media/com.whatsapp/WhatsApp/Media"


def _mtp_relative_to_unixish(relative: str) -> str:
    s = relative.replace("\\", "/").strip("/")
    return f"/{s}" if s else "/sdcard/Android/media/com.whatsapp/WhatsApp/Media"


def build_whatsapp_plan(settings: Settings | None = None) -> WhatsAppCollectorPlan:
    if settings is None or not settings.mtp_whatsapp_media_relative_path:
        return WhatsAppCollectorPlan()
    return WhatsAppCollectorPlan(
        source_path=_mtp_relative_to_unixish(settings.mtp_whatsapp_media_relative_path),
    )
