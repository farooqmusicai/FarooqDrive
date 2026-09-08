# FarooqDrive

**One file manager for multiple Google Drive and Microsoft OneDrive accounts.**

[Open the Web App](https://farooqmusicai.github.io/FarooqDrive/) · [FarooqDrive Website](https://www.mymandoob.com/farooqdrive/) · [Help & Support](https://www.mymandoob.com/farooqdrive/support.html) · [Privacy](https://www.mymandoob.com/farooqdrive/privacy.html) · [Terms](https://www.mymandoob.com/farooqdrive/terms.html)

## Current status — 8 September 2026

The latest Windows test build has been hands-on approved after the preview, indexing, path-display and OneDrive copy corrections. The validated code is now integrated into the `web-update-21-1` branch and the Web App deployment is built from that branch.

The application still displays **Version 21.1** internally until the final Microsoft Store release/version bump is prepared. The most recent validated Windows test package was **21.2.2 Office Preview Test**.

## What FarooqDrive does

FarooqDrive presents multiple cloud-storage accounts in one Explorer-style interface. Users can connect Google Drive and Microsoft OneDrive accounts, browse them separately or through **All Drives**, see provider-reported storage, search across indexed content, find duplicate candidates, preview files, and move/copy files between providers without a FarooqDrive file-storage relay server.

### Multi-account Explorer

- Connect multiple Google Drive and Microsoft OneDrive accounts.
- **All Drives** combines connected accounts into one view.
- Per-account storage used/limit plus combined storage summary.
- Expandable left-side account tree with folders and files.
- Back, Up and breadcrumb navigation.
- Distinct account colors and full account email tooltips.
- Windows-native file/folder icons on Windows; platform-safe icons on Web.
- Eight Explorer-style layouts: Extra large icons, Large icons, Medium icons, Small icons, List, Details, Tiles and Content.
- Sort by Name, Account, Size, Modified and Type; sort direction is remembered.
- Light/Dark mode preference is saved locally.

### File selection and opening

- **Single-click:** selects a file and opens the in-app preview panel.
- **Double-click:** opens the provider's normal browser view.
- Single-click selection no longer launches the browser, which makes drag-and-drop and multi-file work easier.
- A bottom status line shows the selected file as `account email \\ full cloud path \\ filename`.
- Multiple selection shows the selected-item count.

## In-app preview support

FarooqDrive uses a safe preview policy: formats it understands are rendered/extracted in-app; unsupported binary formats are never decoded as fake text. Double-click always remains available for the provider's full browser rendering.

| File type | In-app behavior |
| --- | --- |
| Images | Direct image preview, up to 20 MiB |
| PDF | Real multi-page scrolling PDF viewer, up to 32 MiB |
| Markdown / TXT / CSV / JSON / XML / YAML / source code | Sharp scrollable text preview, up to 2 MiB; text display capped at 250,000 characters |
| Word `.docx` | Extracted readable paragraph/table content |
| Excel `.xlsx` | Worksheet names and real cell values, including shared strings/cached values |
| PowerPoint `.pptx` | Slide text shown in slide order |
| OpenDocument `.odt`, `.ods`, `.odp` | Safe extracted text/sheet/slide content |
| Older binary Office `.doc`, `.xls`, `.ppt` | Provider preview/thumbnail when available; otherwise safe fallback |
| ZIP/RAR/7z, executables, fonts, Apple iWork and unknown binary formats | Provider preview when available; otherwise a clear unsupported-preview message |

The Office preview is intentionally **content-oriented**, not a pixel-perfect replacement for Microsoft Word/Excel/PowerPoint. Full layout, formulas, charts, macros, fonts and advanced formatting should be viewed by double-clicking the file and using the provider's browser editor/viewer.

## Search, background indexing and duplicates

FarooqDrive maintains a saved metadata index so global search and duplicate views do not need to re-read every folder each time.

- On the first run with connected accounts and no valid saved index, FarooqDrive starts a full index automatically **in the background**.
- Users can continue browsing while the scan runs.
- A valid saved index is restored after restart rather than forcing an unnecessary new scan.
- **Rescan all** rebuilds the global index when the user wants fresh cloud state.
- Search can use the global index across connected Drives.
- **Exact duplicates** means matching normalized file name and provider-reported file size. It is a candidate list, not proof of identical content.
- **Same name, different size** highlights naming conflicts.
- Duplicate scanning never deletes files.
- Index changes caused by file operations are marked stale and can be refreshed with Rescan all.

Saved indexes contain file metadata such as names, paths, IDs, sizes and timestamps. They do **not** contain file contents, OAuth tokens or passwords.

## Copy, Cut, Paste, Move and drag-and-drop

FarooqDrive supports cloud-to-cloud operations through the user's device/browser:

- Copy/Paste within or between connected Drives.
- Cut/Move with verification before source cleanup is offered.
- Internal drag-and-drop between folders/accounts.
- New folder, upload, download, rename and Trash/Recycle Bin operations.
- OneDrive destination filenames are normalized when Microsoft rejects Google-compatible characters/reserved names, trailing dots/spaces or unsafe destination names. The source filename is not silently changed on the source provider.

### Transfer safety

FarooqDrive copies first and verifies the destination before any optional source cleanup step.

- Destination content is checked with SHA-256 and an additional verification download.
- Only unchanged OneDrive source files can use conditional Recycle Bin cleanup in the current implementation.
- Google source files are retained when a safe conditional delete cannot be guaranteed.
- Original folder containers are retained.
- Choosing **No** at the cleanup confirmation keeps both copies.
- Interrupted transfers can leave completed destination copies; automatic crash/restart resume is not currently implemented.

## Windows and Web limits

| Capability | Windows | Web |
| --- | --- | --- |
| Google Drive | Yes | Yes |
| Microsoft OneDrive | Yes | Yes, browser OAuth setup required |
| Transfer limit per file | 1 GiB | 32 MiB |
| Temporary transfer staging | Local disk; not encrypted by FarooqDrive | Browser memory |
| Batch safety limit | 10,000 items / 64 folder levels | 10,000 items / 64 folder levels |
| Microsoft session storage | Secure local token storage | Memory-oriented browser session; reconnect may be required after reload |
| Number of connected accounts | No fixed FarooqDrive cap | No fixed FarooqDrive cap; browser resources apply |
| FarooqDrive file relay/storage server | None | None |
| Native Windows file icons | Yes | No; web-safe icons are used |

Provider quotas, Google/Microsoft API policies, tenant consent, browser limits and network conditions still apply.

## Privacy and architecture

FarooqDrive is designed so file content moves directly between the user's device and the selected cloud providers. It does not use a FarooqDrive server as a file-storage relay.

The app may temporarily hold file data locally or in browser memory while performing preview/download/cross-provider copy operations. Windows transfer staging is local temporary disk storage and is not encrypted by FarooqDrive. Browser transfers can use multiple in-memory buffers, so large cloud-to-cloud jobs should use the Windows edition.

Never commit OAuth client secrets, refresh/access tokens, signing certificates, personal scan indexes or user files to this public repository.

## OAuth setup

### Google

Web builds use the configured Google Web OAuth client ID. Windows uses the desktop OAuth configuration. End users/distributors should use their own compliant Google Cloud OAuth setup where required by the release model.

### Microsoft OneDrive

The Entra application for the Web edition requires a **Single-page application** redirect URI:

`https://farooqmusicai.github.io/FarooqDrive/microsoft-callback.html`

Keep the Windows desktop redirect separately for the Windows build. Current delegated permissions are `User.Read` and `Files.ReadWrite`. A client secret must never be embedded in the browser build.

GitHub Actions uses repository configuration/secrets for the public OAuth application IDs during CI/deployment; those values are not stored in source code.

## Source branches and platforms

- **Current validated Windows/Web feature line:** `web-update-21-1`
- **Windows/OneDrive development history:** `onedrive-foundation`
- **Android foundation:** `android-foundation`
- **Flutter application:** `apps/flutter`
- **Earlier desktop code/build artifacts:** `apps/desktop` and `dist`
- **Android and iOS:** planned next after Windows/Web release stabilization.

The Windows and Web editions share the Flutter codebase where platform behavior permits it. Platform-specific authentication, file icons, temporary storage and browser restrictions remain separate where necessary.

## Validation and CI

The latest approved feature set has passed:

- `flutter analyze`
- the full existing Flutter regression suite
- dedicated Word/Excel/PowerPoint package-parser tests
- OneDrive auth/API and cross-provider transfer tests
- saved-index/background-scan tests
- Explorer layout/view tests
- Windows release compilation
- one-click Windows installer packaging
- Web build pipeline, including Microsoft browser-auth tests

Automated tests do not replace live provider acceptance testing. Google/Microsoft tenant consent, quotas, provider-side changes and unusual file/account types still require real-account testing.

## Help and documentation

- [Windows Help](docs/USER-HELP.md)
- [اردو مدد](docs/USER-HELP-URDU.md)
- [OneDrive Guide](docs/ONEDRIVE-GUIDE.md)
- [OneDrive اردو رہنمائی](docs/ONEDRIVE-GUIDE-URDU.md)
- [Web setup, privacy, limits and acceptance checks](docs/WEB-21.1-UPDATE.md)
- [Windows release text](docs/WINDOWS-21.1-RELEASE-TEXT.md)
- [FarooqDrive Website](https://www.mymandoob.com/farooqdrive/)
- [Support](https://www.mymandoob.com/farooqdrive/support.html)
- [Privacy Policy](https://www.mymandoob.com/farooqdrive/privacy.html)
- [Terms](https://www.mymandoob.com/farooqdrive/terms.html)
- [Earlier Version 19 demo video](https://www.youtube.com/watch?v=JrCJkNApJtU)

## Roadmap

1. Finalize Windows release/versioning and Microsoft Store package after the approved test line is frozen.
2. Keep the Web App aligned with the approved Windows/Web Flutter source.
3. Build Android from the same Flutter project with platform-specific OAuth/file handling.
4. Add iPhone/iPad support after Android stabilization.

---

**FarooqDrive** is designed and maintained by Mohammad Farooq. Support: `support@mymandoob.com`.
