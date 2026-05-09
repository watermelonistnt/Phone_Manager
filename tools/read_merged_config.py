"""Emit merged config JSON for MTP scripts; argv[1] is repo root path."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def main() -> None:
    repo = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()
    os.chdir(repo)
    if str(repo) not in sys.path:
        sys.path.insert(0, str(repo))
    from src.config.settings import load_merged_config_dict  # noqa: E402

    print(json.dumps(load_merged_config_dict()))


if __name__ == "__main__":
    main()
