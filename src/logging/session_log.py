from __future__ import annotations

from dataclasses import asdict, dataclass
import json
from pathlib import Path


@dataclass(frozen=True)
class SessionReport:
    device_serial: str
    run_id: str
    verified: bool
    cleanup_allowed: bool
    cleanup_reason: str


def write_session_report(report: SessionReport, run_dir: Path) -> Path:
    run_dir.mkdir(parents=True, exist_ok=True)
    path = run_dir / "session_report.json"
    path.write_text(json.dumps(asdict(report), indent=2), encoding="utf-8")
    return path
