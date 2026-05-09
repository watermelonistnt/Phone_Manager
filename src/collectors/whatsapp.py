from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class WhatsAppCollectorPlan:
    source_path: str = "/sdcard/Android/media/com.whatsapp/WhatsApp/Media"


def build_whatsapp_plan() -> WhatsAppCollectorPlan:
    return WhatsAppCollectorPlan()
