# Operations Runbook

## Standard backup run

1. Connect phone by USB and confirm ADB authorization on device.
2. Run `make run` for default backup pipeline.
3. Review generated report and verification status.

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
