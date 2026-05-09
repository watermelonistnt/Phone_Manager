PYTHON ?= python
PIP ?= $(PYTHON) -m pip

.PHONY: setup lint test run safety mtp-copy-photo mtp-archive-list mtp-archive-one mtp-archive-all mtp-archive-cleanup-hidden nas-media-copy-list nas-media-copy phone-config

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

# Windows: per-file MTP archive (list eligible / one file / all / cleanup quarantine folder).
mtp-archive-list:
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/mtp_nas_archive.ps1 -UseRepoConfig -ListOnly $(if $(DEVICE),-DeviceName "$(DEVICE)",)

mtp-archive-one:
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/mtp_nas_archive.ps1 -UseRepoConfig -MaxFiles 1 $(if $(DEVICE),-DeviceName "$(DEVICE)",)

mtp-archive-all:
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/mtp_nas_archive.ps1 -UseRepoConfig -MaxFiles 0 $(if $(DEVICE),-DeviceName "$(DEVICE)",)

mtp-archive-cleanup-hidden:
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/mtp_nas_archive.ps1 -UseRepoConfig -CleanupHidden $(if $(DEVICE),-DeviceName "$(DEVICE)",)

# Windows: dry run — merged nasMediaRoot + reachability; ok if tmp has no images.
nas-media-copy-list:
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/nas_media_copy.ps1 -ListOnly

# Windows: copy first image under tmp to NAS (needs reachable UNC/SMB share).
nas-media-copy:
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/nas_media_copy.ps1 -MaxFiles 1
