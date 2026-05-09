# Contributing

## Development standards

- Keep changes small and focused.
- Add tests for all behavior changes.
- Prefer explicit, typed interfaces between modules.
- Never weaken cleanup safety gates to pass tests.

## Local workflow

- `make setup` to install tooling
- `make lint` to run Ruff, Black, and mypy checks
- `make test` to run unit and integration tests
- `make run` to execute the CLI entrypoint

## Branch and commit expectations

- Use feature branches for non-trivial work.
- Keep commit messages clear about intent and risk.
- Do not commit local backup artifacts or device data.

## Safe cleanup checklist

Before enabling destructive cleanup in a run:

1. Backup snapshot is complete.
2. Manifest verification succeeded.
3. Session report marks cleanup as eligible.
4. Operator explicitly requested cleanup mode.
