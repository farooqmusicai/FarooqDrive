# FarooqDrive Complete Edition

FarooqDrive presents multiple Google Drive accounts in one file-manager
interface. This repository contains:

- `apps/desktop`: standalone Windows 11 desktop edition (Windows 10 best effort).
- `dist`: install-free web edition.
- `docs`: Google OAuth, usage, build, publishing, privacy, and troubleshooting.

## Non-negotiable credential rule

This repository contains **no developer or user credential**. Every person who
builds or deploys FarooqDrive creates their own Google Cloud project and OAuth
client. Never commit a Client Secret, access token, refresh token, OAuth JSON,
database, or signing certificate.

## Start here

1. Read [Google OAuth setup](docs/GOOGLE-OAUTH-SETUP.md).
2. Windows users read [Windows guide](docs/WINDOWS-GUIDE.md).
3. Web deployers read [Web guide](docs/WEB-GUIDE.md).
4. Read [User help](docs/USER-HELP.md) and [Troubleshooting](docs/TROUBLESHOOTING.md).

## Editions

| Capability | Windows | Web |
| --- | --- | --- |
| Multiple Google accounts | Yes | Yes, current browser session |
| Browse Drive folders | Yes | Yes |
| Upload/download/create folder | Yes | Yes |
| Rename, move, copy, trash | Yes | Yes |
| Search, sort, multi-select | Yes | Yes |
| Unified storage totals | Yes | Yes |
| Local secrets | Encrypted on the PC | No secret is used |
| Server storage | None | None |

## Status

Version 1.1.0 is a release candidate until Google OAuth is verified with the
owner's production domains and the Windows installer is tested on clean Windows
11 and Windows 10 machines.

Cross-account copy intentionally uses a download-then-upload workflow in this
release; direct streamed transfer remains on the production checklist. See
[release status](docs/RELEASE-STATUS.md).
