# FarooqDrive Desktop Architecture

## Desktop shell
Electron provides a Windows desktop window and packages the React UI plus local service into a self-contained desktop application.

## Local service
Express listens only on `127.0.0.1` and uses a random available port. The React application is served from the same local origin. Non-loopback connections are rejected.

## Database
FarooqDrive uses SQLite through Node's built-in SQLite API. The database is stored inside the application's Windows user-data directory; no database server is installed.

## Local secrets
On Windows/Electron, a random application master key is protected with Electron safe storage when available. Google refresh tokens are encrypted with AES-256-GCM before being written to SQLite. Session authentication uses a local HttpOnly cookie signed with a key derived from the master key.

## Google authorization
The application uses a Google OAuth Desktop application client and a loopback redirect. Authorization opens in the system browser, not inside an embedded login frame. A random state is kept locally and the Electron UI polls the local service until authorization completes.

## File placement
Each connected Google account has a `Farooqdrive` folder. File bytes are uploaded to Google Drive using a resumable upload session. The local database stores metadata and virtual folder mapping.

## Virtual folders
Virtual folders are independent from physical Google Drive folders. This lets one FarooqDrive virtual folder contain files physically stored in different Google accounts.

## Google OAuth scope
FarooqDrive requests full `https://www.googleapis.com/auth/drive` authorization so the unified storage layer can discover/sync manually-added files in each account's `Farooqdrive` folder and perform the intended file operations. The scope is broader than FarooqDrive's intended folder boundary and is classified by Google as restricted.
