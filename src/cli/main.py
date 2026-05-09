from __future__ import annotations

import argparse
from pathlib import Path

from src.config.phone_config import ensure_phone_config_file
from src.config.settings import load_settings
from src.core.pipeline import run_backup_pipeline


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="phone-manager")
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser(
        "phone-init",
        help="Create ignored config.phone.json from config.phone.example.json if missing.",
    )
    init_parser.add_argument(
        "--repo-root",
        type=Path,
        default=None,
        help="Repository root (default: current working directory).",
    )

    run_parser = subparsers.add_parser(
        "run", help="Run backup pipeline (MTP-first desktop; see docs/operations.md)."
    )
    run_parser.add_argument(
        "--cleanup",
        action="store_true",
        help="Request cleanup mode (still subject to safety gates).",
    )
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    if args.command == "phone-init":
        root = args.repo_root or Path.cwd()
        path = ensure_phone_config_file(root)
        print(f"Phone config: {path.resolve()}")
        return

    if args.command == "run":
        settings = load_settings()
        result = run_backup_pipeline(settings=settings, explicit_cleanup=args.cleanup)
        print(f"Run folder: {result.run_dir}")
        print(f"Manifest: {result.manifest_path}")
        print(f"Report: {result.report_path}")
        print(f"Cleanup decision: {result.decision.reason}")


if __name__ == "__main__":
    main()
