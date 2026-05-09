from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    backup_root: Path = Path("data/backups")
    logs_root: Path = Path("logs")
    cleanup_dry_run_default: bool = True


def load_settings() -> Settings:
    return Settings()
