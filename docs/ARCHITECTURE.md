# Architecture

## Windows

Electron renderer → isolated preload IPC → Electron main process → Google OAuth
loopback + Google Drive REST API. SQLite contains the local index; Electron
safeStorage protects OAuth configuration and tokens where the OS supports it.
Uploads stream from the user's PC to Google Drive.

## Web

Static HTML/CSS/JavaScript → Google Identity Services token client → Google Drive
REST API. No FarooqDrive backend receives files or Google access tokens. The
public Web Client ID is stored as a browser preference; tokens live only in page
memory and disappear on reload.

## Repository safety boundary

Committed: source, icons, examples, build workflow, help, privacy template.
Never committed: OAuth secrets, tokens, databases, personal files, certificates,
real environment files, or signed Store packages.
