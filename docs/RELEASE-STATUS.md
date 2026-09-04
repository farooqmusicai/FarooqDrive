# Release status — 1.1.0 RC

## Implemented in source

- Windows and responsive web file-manager layouts.
- Multiple account connection and account switching.
- Folder navigation, search, sorting, multi-select, create folder, upload.
- Same-account copy/move and Google Drive Trash.
- Unified quota display.
- BYO OAuth and credential-free repository policy.
- Windows build and GitHub Pages workflows.
- English/Urdu setup, security, privacy, user-help, and troubleshooting material.

## Required before calling it production-final

- Test real Google OAuth on the final HTTPS origin.
- Test installer/portable builds on clean Windows 11 and Windows 10.
- Verify large uploads, refresh tokens, Google-native files, shared items, and
  rate-limit/error recovery.
- Implement and test streamed cross-account copy. Current safe flow is download
  then upload; the UI does not silently buffer large files.
- Complete Google OAuth production verification if the app will be available to
  users outside the deployer's test-user list.
- Reserve Microsoft Store identity, build/sign MSIX, and pass certification.

No document or version label should represent these external tests as completed
until their evidence exists.
