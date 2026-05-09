from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class CleanupDecision:
    allowed: bool
    reason: str


def evaluate_cleanup(
    verified: bool, explicit_cleanup: bool, dry_run_default: bool
) -> CleanupDecision:
    if not verified:
        return CleanupDecision(False, "blocked: manifest verification not successful")
    if not explicit_cleanup:
        return CleanupDecision(False, "blocked: cleanup not explicitly requested")
    if dry_run_default:
        return CleanupDecision(False, "blocked: dry-run default enabled")
    return CleanupDecision(True, "allowed")
