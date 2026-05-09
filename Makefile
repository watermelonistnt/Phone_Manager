PYTHON ?= python
PIP ?= $(PYTHON) -m pip

.PHONY: setup lint test run safety mtp-copy-photo phone-config

setup:
	$(PYTHON) -m venv .venv
	.venv/Scripts/python -m pip install --upgrade pip
	.venv/Scripts/python -m pip install -e ".[dev]"

lint:
	.venv/Scripts/python -m ruff check .
	.venv/Scripts/python -m black --check .
	.venv/Scripts/python -m mypy src

test:
	.venv/Scripts/python -m pytest

safety:
	.venv/Scripts/python tools/check_repo_safety.py

run:
	.venv/Scripts/python -m src.cli.main run

phone-config:
	.venv/Scripts/python -m src.cli.main phone-init

# Windows: MTP copy using merged config (optional DEVICE= overrides this-PC name substring).
mtp-copy-photo:
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/mtp_copy.ps1 -UseRepoConfig $(if $(DEVICE),-DeviceName "$(DEVICE)",)
