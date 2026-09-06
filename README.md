# FarooqDrive 21.1

Your Google Drive and Microsoft OneDrive accounts in one file manager.

[Open the Web App](https://farooqmusicai.github.io/FarooqDrive/) · [Website](https://www.mymandoob.com/farooqdrive/) · [Help and support](https://www.mymandoob.com/farooqdrive/support.html)

## Microsoft OneDrive

Connect OneDrive alongside Google Drive using **Add account → Microsoft OneDrive**. Personal Microsoft accounts and work/school accounts are supported by the sign-in configuration; organizational access depends on tenant consent and OneDrive availability.

- Browse each connected account's folders, files and provider-reported storage, or use All Drives for a combined view.
- Upload, download, create folders, rename and copy files. Use the same toolbar, sorting, views and internal drag-and-drop for both providers.
- Copy between Google Drive and OneDrive through your device, with destination verification. Cut/Move follows the final-confirmation rules below.
- Keep accounts separate: each row identifies its account, and hovering over the account shows its full name and email.

**Owner verification, 6 September 2026:** OneDrive sign-in, folder listing and storage display work in the published Web App. This confirms browsing; it is not a claim that every account type or transfer scenario has been tested.

[OneDrive guide](docs/ONEDRIVE-GUIDE.md) · [OneDrive اردو رہنمائی](docs/ONEDRIVE-GUIDE-URDU.md)

## Explorer features

- Expand account folders in the left panel; browse with Back, Up and breadcrumbs.
- Eight views: Extra large, Large, Medium and Small icons, List, Details, Tiles and Content.
- Saved Light/Dark preference, full account-name/email tooltips, and remembered Name, Account, Size and Modified sorting across tabs.
- Background duplicate scans with page progress and saved metadata indexes. Continue working during scans; Rescan all refreshes the index. Matching name and size identifies candidates, not proven identical contents. Scans never delete files.
- Upload, download, new folder, rename, Copy/Paste and internal drag-and-drop. Cut/Move copies and verifies before asking for final source cleanup.

## Transfer safety and limits

Destination content is verified with SHA-256 and an extra download before cleanup is offered. Only unchanged OneDrive source files support conditional Recycle Bin cleanup. Google originals and original folder containers remain. Choosing No keeps both copies. Interrupted operations may leave destination copies; no automatic restart resume is available.

| Capability | Windows 21.1 | Web 21.1 |
| --- | --- | --- |
| Google Drive and OneDrive | Yes | Yes, browser sign-in setup required |
| Transfer limit per file | 1 GiB | 32 MiB |
| Temporary staging | Local disk, not encrypted by FarooqDrive | Browser memory, potentially several buffers |
| Batch limit | 10,000 items / 64 folder levels | 10,000 items / 64 folder levels |
| Microsoft account session | Secure local token storage | Memory-only; reconnect after reload |
| Account count | No fixed app cap | No fixed app cap; browser resources apply |
| File-storage relay server | None | None |

Provider quotas, tenant consent and browser restrictions apply. Keep the web tab open until a transfer completes. Internal dragging is supported; the app does not mount cloud accounts as Windows drives or implement all Windows Explorer clipboard features.

[Web setup, privacy, limits and acceptance checks](docs/WEB-21.1-UPDATE.md)

## Platforms and source

- **Windows:** [onedrive-foundation branch](https://github.com/farooqmusicai/FarooqDrive/tree/onedrive-foundation). Store packaging/release is a separate step.
- **Web:** [web-update-21-1 branch](https://github.com/farooqmusicai/FarooqDrive/tree/web-update-21-1). The Pages workflow pins a tested web commit so web updates do not replace the Windows release source.
- **Android, iPhone/iPad and macOS apps:** coming soon.
- `apps/flutter`: current application source. `apps/desktop` and `dist`: earlier editions.

Version remains **21.1**. Availability of a source change does not imply a new Microsoft Store submission.

## Setup and credentials

For web OneDrive, the existing Entra registration needs a **Single-page application** redirect at `https://farooqmusicai.github.io/FarooqDrive/microsoft-callback.html`. Keep the Windows `http://localhost` desktop redirect. Delegated permissions are `User.Read` and `Files.ReadWrite`; no client secret belongs in the browser.

Builds use the existing GitHub configuration `FAROOQDRIVE_WEB_CLIENT_ID` for Google and `FAROOQDRIVE_MICROSOFT_CLIENT_ID` for Microsoft. These supply public OAuth application IDs. Never commit client secrets, access/refresh tokens, signing certificates or personal scan data.

Microsoft branding URLs and a logo do not complete publisher verification. Google consent publishing/verification and organization policies still apply. See the [web guide](docs/WEB-21.1-UPDATE.md).

## Help, privacy and release notes

- [Windows Help](docs/USER-HELP.md) · [اردو مدد](docs/USER-HELP-URDU.md)
- [Privacy](https://www.mymandoob.com/farooqdrive/privacy.html) · [Terms](https://www.mymandoob.com/farooqdrive/terms.html)
- [Windows release text](docs/WINDOWS-21.1-RELEASE-TEXT.md)
- [Earlier Version 19 demonstration](https://www.youtube.com/watch?v=JrCJkNApJtU)

The app communicates directly with cloud providers. Saved indexes contain file metadata, not file content or OAuth tokens. See platform-specific Help for local storage and cleanup details. Authenticated cloud-operation acceptance must be checked with owner test accounts; CI tests do not prove live tenant consent.
