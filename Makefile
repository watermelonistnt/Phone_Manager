PYTHON ?= python
PIP ?= $(PYTHON) -m pip

.PHONY: setup lint test run safety mtp-copy-photo

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

# Windows: copy first camera image to tmp/mtp-incoming via MTP (no adb). Optional DEVICE=name substring.
mtp-copy-photo:
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/mtp_copy.ps1 $(if $(DEVICE),-DeviceName "$(DEVICE)",)
