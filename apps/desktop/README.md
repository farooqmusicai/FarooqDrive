# FarooqDrive

FarooqDrive is a standalone Windows desktop application that combines multiple Google Drive accounts into one unified storage dashboard.

## Core behavior

- Connect multiple Google Drive accounts.
- Show combined Total / Used / Free storage.
- Keep FarooqDrive-managed files under a `Farooqdrive` folder in each connected Google account.
- Route each upload automatically to the connected account with enough free space, preferring the account with the most available space.
- Stream uploads from the desktop app directly to Google Drive. Files are not copied to an intermediate server.
- Maintain local virtual folders that can contain files stored across different Google accounts.
- Manual sync imports files found under each account's `Farooqdrive` folder.
- Preview, download, rename, move virtually, and delete files.
- Store Google OAuth credentials and account tokens encrypted with Windows/Electron secure storage.
- Use embedded SQLite in the desktop app. No MySQL, Docker, Node.js, or local server is required for end users.

## Google Cloud setup

Each user supplies their own Google OAuth Desktop App credentials.

1. Create/select a Google Cloud project.
2. Enable Google Drive API.
3. Configure Google Auth Platform / OAuth consent screen.
4. Add test users while the app is in Testing mode.
5. Create OAuth Client type **Desktop app**.
6. Copy Client ID and Client Secret into FarooqDrive Settings.

FarooqDrive requests:

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/drive`

The full Drive scope is used so FarooqDrive can discover, sync, rename, download, and delete files that exist inside the managed `Farooqdrive` folder.

## Build

GitHub Actions: **Actions → Build Windows Release → Run workflow**.

The workflow produces both an installer and a portable Windows x64 EXE.

## Copyright

Copyright © 2026 Mohammad Farooq. All Rights Reserved.
