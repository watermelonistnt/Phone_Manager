from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass(frozen=True)
class Manifest:
    device_serial: str
    run_id: str
    copied_items: int
    verified: bool


def write_manifest(manifest: Manifest, run_dir: Path) -> Path:
    run_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = run_dir / "manifest.json"
    manifest_path.write_text(json.dumps(asdict(manifest), indent=2), encoding="utf-8")
    return manifest_path
