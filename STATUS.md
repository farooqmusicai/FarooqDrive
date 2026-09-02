# Release Status - 0.9.3 Release Candidate Source

FarooqDrive 0.9.3 is a credential-free, standalone Windows release candidate source tree. It is **not yet a signed final public production binary**.

## Completed
- Windows standalone architecture with embedded SQLite; no Docker/MySQL required for end users.
- Official FarooqDrive database-and-folders branding and Windows/Store icon assets.
- Credential-free GitHub and Windows build architecture.
- First-run Google OAuth setup wizard.
- Each installation stores its own Google Desktop OAuth Client ID and Client Secret in encrypted local application storage.
- OAuth Settings page for later credential management.
- `drive.file` is the intended minimal Google Drive scope.
- GitHub Actions builds no longer require publisher Google OAuth credentials.
- Setup EXE and Portable EXE have distinct artifact names.

## Still required before final 1.0 public release
1. Build the actual Windows EXE on a Windows runner and perform Windows 11 clean-machine tests.
2. Final review/update of the live FarooqDrive privacy, terms and support pages so they exactly match the 0.9.3 implementation.
3. Reserve the FarooqDrive app identity in Microsoft Partner Center and insert final Store identity values.
4. Complete Microsoft Store packaging/testing.
5. Optional trusted code signing for direct-download installers outside Microsoft Store.

## Important architecture rule
The official public binaries contain **no publisher Google OAuth Client ID or Client Secret**. Every user creates and uses their own Google OAuth Desktop client. Existing Drive accounts must be disconnected before the OAuth client is replaced because refresh tokens belong to the client that created them.
