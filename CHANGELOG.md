# Changelog

## 0.9.4 - 2026-09-02
- Restored the original unified multi-Google-Drive scope model.
- Changed OAuth from `drive.file` to full `https://www.googleapis.com/auth/drive`.
- Updated first-run Google setup instructions and disclosure for Google's restricted full-Drive permission.
- Updated README, Privacy, Terms, Security and Store listing text to match actual permission behavior.
- Carried forward Windows CI fixes (`vite-env.d.ts` and `--publish never`).

## 0.9.3 - 2026-09-02
- Changed the public Windows edition to Bring Your Own Google OAuth credentials.
- Added an automatic first-run Google Cloud/OAuth setup wizard.
- Added encrypted local storage for each installation's Client ID and Client Secret.
- Added an OAuth Settings page and safe replacement rule requiring Drive accounts to be disconnected first.
- Removed publisher Google OAuth credentials from the Windows packaging process and GitHub Actions build.
- Updated privacy, terms, README and Windows build documentation for credential-free distribution.

## 0.9.2 - 2026-09-02
- Hardened OAuth credential handling for public GitHub distribution.
- Added credential-free GitHub Actions Windows build flow using Repository Secrets.
- Added separate Setup and Portable EXE artifact names.
- Added local private `google-oauth.json` loading for publisher testing.
- Added Urdu Windows cloud-build guide.

## 0.9.1 - 2026-09-02
- Adopted the owner-approved database-and-folders artwork as the official FarooqDrive icon.
- Added multi-resolution Windows `FarooqDrive.ico` and packaged window PNG.
- Wired Electron Builder and the desktop BrowserWindow to the official icon.
- Added Microsoft Store/MSIX `StoreLogo`, `Square44x44Logo`, and `Square150x150Logo` assets.
- Added GitHub/repository branding exports and updated branding documentation.

## 0.9.0 - 2026-09-02
- Converted the development architecture to a Windows desktop architecture.
- Replaced the external MySQL requirement with an embedded SQLite database.
- Added Electron desktop shell and loopback-only local service.
- Added system-browser Google OAuth flow with authorization polling.
- Added multi-account Drive quota dashboard, upload selection, virtual folders, manual sync, preview, download, rename, virtual move, trash and account disconnect.
- Added GitHub, legal and Microsoft Store release material.
