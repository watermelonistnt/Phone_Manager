from __future__ import annotations

from pathlib import Path
import subprocess
import sys


REQUIRED_EXAMPLES = (
    ".env.example",
    "config.example.json",
)

FORBIDDEN_TRACKED_PATHS = (
    ".env",
    "config.local.json",
    "secrets.local.json",
)

FORBIDDEN_SUFFIXES = (
    ".pem",
    ".key",
    ".p12",
    ".jks",
    ".keystore",
    ".mobileprovision",
)


def get_tracked_files() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError("Unable to list tracked files with git ls-files.")
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def main() -> int:
    errors: list[str] = []

    for required in REQUIRED_EXAMPLES:
        if not Path(required).exists():
            errors.append(f"Missing required example file: {required}")

    tracked = get_tracked_files()
    tracked_set = set(tracked)

    for forbidden in FORBIDDEN_TRACKED_PATHS:
        if forbidden in tracked_set:
            errors.append(f"Forbidden tracked secret file detected: {forbidden}")

    for tracked_file in tracked:
        lower_file = tracked_file.lower()
        if lower_file.endswith(FORBIDDEN_SUFFIXES):
            errors.append(f"Forbidden tracked credential-like file detected: {tracked_file}")

    if errors:
        print("Repository safety check failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Repository safety check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
