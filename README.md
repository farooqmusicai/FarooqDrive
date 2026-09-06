# FarooqDrive

## Windows 21.1 — Google Drive and Microsoft OneDrive

The `onedrive-foundation` branch provides the Windows update. The owner reported
that the previous upload/transfer build works. This revision adds saved Light/Dark
mode, sortable columns across all tabs, and a persistent background scan index.
The version display stays 21.1 and no longer says Test.

Scan results survive ordinary Refresh, tab changes and app restarts. Rescan all
builds a replacement while the previous snapshot remains available. Metadata
matches are duplicate suggestions, not proof of identical contents. File changes
mark the snapshot outdated. No scan deletes files.

Use the Windows Help for verified-transfer behavior and its limits, including
retained Google originals and folder containers, 1 GiB transfers, temporary disk
storage, and separate final confirmation for eligible OneDrive cleanup.

- [Windows Help](docs/USER-HELP.md) · [اردو مدد](docs/USER-HELP-URDU.md)
- [Privacy](docs/PRIVACY.md) · [Terms](docs/TERMS.md)
- [Store text and console actions](docs/WINDOWS-21.1-RELEASE-TEXT.md)

The published web/mobile editions and Microsoft Store package are not updated by
this feature-branch build. Their availability must not be inferred from the
Windows description below.


## Live Web App

[Open FarooqDrive in your browser](https://farooqmusicai.github.io/FarooqDrive/)

This public GitHub Pages edition is provided for testing the Web application.

## Demo Video

[Watch the FarooqDrive Windows and Web demonstration on YouTube](https://www.youtube.com/watch?v=JrCJkNApJtU)

The video demonstrates FarooqDrive Version 19, Google account connection, the
unified Drive interface, storage information, and file-management workflow.

## Screenshots

### All Drives — ready to connect

![FarooqDrive All Drives screen](docs/screenshots/farooqdrive-all-drives.png)

### Connected accounts and file management

![FarooqDrive connected Drive screen](docs/screenshots/farooqdrive-connected-drive.png)

FarooqDrive presents multiple Google Drive accounts in one file-manager
interface. This repository contains:

- `apps/flutter`: cross-platform edition; Web is the first reference platform.
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
2. Windows users read the [English guide](docs/WINDOWS-GUIDE.md) or
   [Urdu guide](docs/WINDOWS-GUIDE-URDU.md).
3. Web deployers read [Web guide](docs/WEB-GUIDE.md).
4. Read User Help in [English](docs/USER-HELP.md) or
   [Urdu](docs/USER-HELP-URDU.md), plus [Troubleshooting](docs/TROUBLESHOOTING.md).
5. Review Privacy in [English](docs/PRIVACY.md) or
   [Urdu](docs/PRIVACY-URDU.md), and Terms in [English](docs/TERMS.md) or
   [Urdu](docs/TERMS-URDU.md).

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

Version 21 is a release candidate until the safe Windows startup and responsive update are tested
and Google OAuth is verified with the
owner's production domains and the Windows installer is tested on clean Windows
11 and Windows 10 machines.

Cross-account copy intentionally uses a download-then-upload workflow in this
release; direct streamed transfer remains on the production checklist. See
[release status](docs/RELEASE-STATUS.md).
