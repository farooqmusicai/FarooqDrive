# FarooqDrive

Independent Windows desktop application for combining multiple Google Drive accounts into one unified storage dashboard.

## Features
- Multiple Google Drive accounts and combined quota
- Automatic upload routing to the account with the most available space
- Dedicated `Farooqdrive` root folder in each Google account
- Direct desktop-to-Google resumable upload streaming
- Embedded SQLite; no MySQL, Docker, Node.js or server required for end users
- Manual recursive sync of managed Drive folders
- Local virtual folders spanning different Google accounts
- Preview, download, rename, virtual move, and Trash
- OAuth credentials and tokens encrypted using Electron/Windows secure storage
- User-supplied Google OAuth Desktop App credentials

## Google setup
Enable Google Drive API, configure Google Auth Platform, create a Desktop app OAuth client, and add every account as a Test user while the OAuth app is in Testing mode. FarooqDrive requests `openid`, `email`, `profile`, and `https://www.googleapis.com/auth/drive`.

## Windows build
Open GitHub Actions → Build Windows Release → Run workflow. Download the `FarooqDrive-Windows` artifact when the run succeeds.

Copyright © 2026 Mohammad Farooq. All Rights Reserved.
