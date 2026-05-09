PYTHON ?= python
PIP ?= $(PYTHON) -m pip

.PHONY: setup lint test run safety

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
