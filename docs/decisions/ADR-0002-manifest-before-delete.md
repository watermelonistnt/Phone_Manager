# ADR-0002: Manifest verification required before delete

## Status

Accepted

## Context

Data loss risk is unacceptable for family photos and chat exports.

## Decision

Only allow cleanup when manifest verification has completed successfully.

## Consequences

- Stronger safety guarantees
- Extra processing time for hash verification
- Cleaner audit trail for each run
