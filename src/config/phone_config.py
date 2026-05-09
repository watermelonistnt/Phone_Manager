"""Create ``config.phone.json`` from the tracked example when missing (operator bootstrap)."""

from __future__ import annotations

import shutil
from pathlib import Path


def ensure_phone_config_file(repo_root: Path | None = None) -> Path:
    """Copy ``config.phone.example.json`` to ``config.phone.json`` if the latter is absent.

    Returns the path to ``config.phone.json`` (existing or newly created).
    """
    root = repo_root or Path.cwd()
    dest = root / "config.phone.json"
    if dest.is_file():
        return dest
    src = root / "config.phone.example.json"
    if not src.is_file():
        raise FileNotFoundError(
            f"Cannot bootstrap phone config: missing template {src.name} in {root}.",
        )
    shutil.copyfile(src, dest)
    return dest
