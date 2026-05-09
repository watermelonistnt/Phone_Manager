# Operations Runbook

## Standard backup run (Python pipeline)

1. Copy `config.example.json` to ignored `config.local.json` and set **`backup.deviceId`** to a short logical name for this phone (used under `data/backups/<deviceId>/...`) **unless** you use nested profiles (below). Do not commit secrets, real NAS paths, or personal **This PC** phone display strings you do not want in git.
2. Set optional **`storage.nasMediaRoot`** in `config.local.json` if you track where NAS copies should go later.
3. Connect the phone with USB **File transfer / MTP** when using Windows copy helpers.
4. Run `make run` (or `python -m src.cli.main run`). Review the printed run folder, manifest, and report.

### Per-user phones (`config.local.json` only)

Use this when one machine backs up **multiple people** or **multiple phones**, or you swap handsets: define **`users.<userKey>.phones.<phoneKey>`** and select the active pair with **`activeUserId`** + **`activePhoneId`**. Tracked [`config.example.json`](config.example.json) shows placeholder keys only; put real values (for example the exact string shown under **This PC** for your phone) in **`config.local.json`** only.

- **`thisPcDeviceNameSubstring`**: substring match for MTP (`tools/mtp_copy.ps1` **`-DeviceName`**).
- **`backupDeviceId`**: folder-safe id used for Python snapshots / manifest logical id (overrides top-level **`backup.deviceId`** when the profile resolves).
- **`mtp.relativePath`**: use **`AUTO`** or empty for `**/DCIM/Camera` discovery; otherwise an explicit backslash path.
- **`mtp.maxSearchDepth`**: optional positive integer (default **20**).

If **`activeUserId`** / **`activePhoneId`** are missing or the path does not resolve, the app falls back to top-level **`backup.deviceId`** as before.

`make mtp-copy-photo` passes **`-UseRepoConfig`** so MTP defaults come from merged config when you omit CLI flags. Use **`make mtp-copy-photo DEVICE=OtherName`** to override the This-PC substring for one run.

## MTP copy (Windows, primary phone access)

Use when the phone appears under **This PC** in File Explorer (USB **File transfer / MTP**). No Android Platform Tools required.

Add **`-UseRepoConfig`** to pull **`-DeviceName`**, **`-RelativePath`**, and **`-MaxSearchDepth`** from the merged config when you omit those parameters (see **Per-user phones** above). `make mtp-copy-photo` passes **`-UseRepoConfig`** by default.

1. Unlock the phone and accept any trust prompts.
2. From the repo root, list what would be copied (no files written):

   `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\mtp_copy.ps1 -UseRepoConfig -ListOnly`

3. If the script says multiple devices, pass a unique substring of the phone name:

   `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\mtp_copy.ps1 -DeviceName "YourPhone" -ListOnly`

4. Copy the first image to **`tmp/mtp-incoming`** (gitignored). By default the script **searches** under the internal volume for a **`DCIM/Camera`** folder (same tree as **This PC → your phone → internal storage → DCIM → Camera**). If MTP shows **only one** navigable folder under the phone (typical), that folder is treated as internal storage even when its display name does not match the built-in English/Chinese alias list.

   `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\mtp_copy.ps1 -DeviceName "YourPhone"`

5. If the camera roll lives deeper or under an unusual tree, raise the search depth:

   `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\mtp_copy.ps1 -DeviceName "YourPhone" -MaxSearchDepth 28`

6. If your OEM does not use `DCIM/Camera`, pass an explicit path (still backslashes); if the first segment is English `Internal storage`, localized internal-volume names are still tried for that segment:

   `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\mtp_copy.ps1 -DeviceName "YourPhone" -RelativePath "Internal storage\DCIM\OpenCamera" -MaxFiles 1`

   You can also pass `-RelativePath` with exact folder names as shown in Explorer.

**Note:** This uses the same Shell layer as Explorer. For scripting, prefer stable **`DeviceName`** / **`RelativePath`** values in your own notes or `config.local.json` (not committed) rather than hardcoding device display strings in tracked files.

## Verification

- Ensure `manifest.json` exists in the run folder.
- Confirm verifier result is `ok`.
- Confirm report includes copied file counts and hash summary.

## Cleanup run

1. Start with dry-run cleanup mode.
2. Review delete candidates from report output.
3. Run explicit cleanup only after successful verification.

## Rollback and incident handling

- If verification fails, do not delete source files.
- Preserve session logs and manifests for diagnosis.
- Re-run backup after fixing connection or storage issues.
