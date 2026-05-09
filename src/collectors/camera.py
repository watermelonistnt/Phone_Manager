from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class CameraCollectorPlan:
    source_path: str = "/sdcard/DCIM/Camera"


def build_camera_plan() -> CameraCollectorPlan:
    return CameraCollectorPlan()
