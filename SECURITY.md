# Security Policy

## Supported releases
Security fixes are provided for the latest stable FarooqDrive release and, when practical, the immediately preceding stable release.

## Reporting a vulnerability
Please do not open a public GitHub issue for an unpatched vulnerability. Send a private report to **[ADD SECURITY EMAIL]** with the affected version, reproduction steps, impact, and any proof of concept. Do not include Google refresh tokens, passwords, private files, or other users' personal information.

## Security design
- Google authentication uses OAuth; FarooqDrive never asks for a Google password.
- The desktop OAuth callback listens on the loopback interface only.
- OAuth refresh tokens are encrypted at rest using an application master key protected by the Windows/Electron secure-storage mechanism when available.
- The local HTTP service binds to `127.0.0.1` only and rejects non-local connections.
- The app requests the narrower Google Drive `drive.file` permission.
- File uploads use Google Drive resumable uploads; FarooqDrive does not intentionally persist file bytes in its local database.

## Secrets
Never commit real OAuth credentials, code-signing certificates, certificate passwords, GitHub tokens, Microsoft Store credentials, or user tokens. Use GitHub Actions Secrets and the ignored release configuration files.
