# Release Status - 0.9.4 Release Candidate Source

FarooqDrive 0.9.4 restores the original unified multi-Google-Drive product model and changes Google authorization to the full `drive` scope required for that model's manual sync and complete managed-file operations.

## Completed
- Multiple Google Drive accounts represented in one virtual dashboard.
- Aggregate quota and smart upload-account selection.
- Per-account `Farooqdrive` root folders.
- Virtual folders and per-file account mapping.
- Manual sync from connected `Farooqdrive` folders.
- Preview/download/rename/move/delete plumbing for managed files.
- Credential-free BYOC Windows/GitHub architecture.
- Full Google Drive OAuth scope for unified sync/file-manager behavior.
- Official FarooqDrive branding.
- Windows build fixes: Vite client types and `--publish never` for CI artifact builds.

## Important Google requirement
`https://www.googleapis.com/auth/drive` is a Google restricted scope. Each BYOC user owns the Google Cloud project they configure and is responsible for Google's applicable testing/publishing/verification requirements.

## Still required before final 1.0
1. Update the test Google Cloud project's Data Access from `drive.file` to `drive`.
2. Re-authorize the test account so the new token contains the full Drive scope.
3. Build Windows v0.9.4 and run clean functional tests with at least two Google accounts.
4. Review live privacy/terms pages against this full-scope design.
5. Complete Microsoft Store identity/package testing.
