# Environment Setup (AGENT Ready)

## Baseline

- Python 3.12
- Android Platform Tools (`adb`)
- Git + GitHub CLI (`gh`)

## Setup options

### Option A: Make

- `make setup`
- `make lint`
- `make test`
- `make run`

### Option B: PowerShell direct commands

- `python -m venv .venv`
- `.\\.venv\\Scripts\\python -m pip install --upgrade pip`
- `.\\.venv\\Scripts\\python -m pip install -e ".[dev]"`
- `.\\.venv\\Scripts\\python -m ruff check .`
- `.\\.venv\\Scripts\\python -m black --check .`
- `.\\.venv\\Scripts\\python -m mypy src`
- `.\\.venv\\Scripts\\python -m pytest`
- `.\\.venv\\Scripts\\python -m src.cli.main run`
