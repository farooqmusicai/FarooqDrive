# FarooqDrive: Windows-first OneDrive implementation

## Current Windows 21.1 update — 6 September 2026

Owner reported the previous build works. New theme, sorting, persistent background
scan and full account hover changes passed Analyze, tests and Windows packaging.

- Tested runtime: `630c7ac2af10907199869ddad9848fd6e4dedb79`.
- Workflow: `34055324289`; job: `101546087971`.
- FarooqDrive-Windows-Installer: `9995837248`, 10668603 bytes, `sha256:857a7ca928409e89d02248d7adbf2d29a70f66785ab6f1cbd8171883ba6009f1`.
- FarooqDrive-Windows-x64: `9995836913`, 12780678 bytes, `sha256:65597b6ad97de2b7c1eb52530ee8bbf9c1ddd527ea48841369b4003b087d3d47`.
- Display stays 21.1 without Test; pubspec stays 21.1.0+22.
- Light/Dark and shared column sorting persist. Full account name/email on hover.
- Scans run without blocking navigation. A local metadata index survives tabs,
  Refresh and restart. Rescan all replaces it only on success. Mutations mark it
  outdated and reject an inconsistent scan. No tokens/contents in saved index.
- English/Urdu Help, Privacy, Terms and README updated; Store copy and console
  guidance are in WINDOWS-21.1-RELEASE-TEXT.md.
- Live website, main, mobile and Store distribution remain unchanged. Website
  publication needs hosting/source access; Store submission needs the matching
  accepted MSIX. Console verification status was not checked in owner consoles.
  No new OAuth scopes are introduced by this update.

## Historical compact explorer checkpoint


Status: Owner reported the app runs well, requested a compact explorer layout and eight views, and reported OneDrive local-upload failures and inconsistent internal drops. The updated candidate passed Analyze, all 29 tests, Windows compilation and both packages. Owner re-testing of authenticated OneDrive uploads is still required; the original live failure was not reproduced using the owner's credentials. See [current scope and limitations](WINDOWS-VERIFIED-TRANSFERS.md).

## Current compact explorer / local upload candidate

- Exact tested commit: `287cfa5fd36445c27dd1fafb571bf72005c0ab30`.
- Successful workflow: `34052308546`; job: `101537980454`.
- Portable artifact: `9994971278`, 12,768,449 bytes;
  SHA-256 `c99a711bc133e38f86ac4895c4638b2438183532345ea59a0458041d78e4000f`.
- Installer artifact: `9994971602`, 10,657,708 bytes;
  SHA-256 `c598f4b59c1dc07f766e934e819cb29be64987098776a4bbcb0153d7d587136a`.
- Back/Up/breadcrumbs/actions share one row; Name and eight-option View are on the
  right. Disclosure/results/errors moved into a red information dialog next to
  history. Account name/email fonts are equal, 13 px. Text provider labels remain.
- Blank current-folder area and breadcrumbs now accept internal drops. Empty
  stale drag selections fall back to the dragged item. Existing source cleanup
  confirmation and conditional-trash safeguards are retained.
- Windows file-picker uploads now stream through disk, upload, and verify SHA-256.
  OneDrive <=4 MiB uses direct PUT with URL rename-on-conflict and one 401 token
  refresh; larger files use upload sessions. Error codes are sanitized and shown.
- Regression checks cover all eight layouts, navigation/action row alignment,
  information text style, a real Flutter drag gesture into blank space, small and
  zero-byte OneDrive request shape, token renewal and local-upload corruption.
- Next owner check: upload a small local TXT/image to OneDrive root and a folder,
  then drag a cloud test file onto the destination pane's blank area. If upload
  still fails, obtain the exact error from the red information dialog/Activity.
- No Store submission, main merge, version increase or Android branch update.

## Previous verified-transfer candidate

- Exact runtime commit: `a6d69037c92fbb93c18eba82c0f30581a09d81e5`.
- Successful workflow: `34049666817`; job: `101530868965`.
- Portable artifact: `9994208046`, 12,761,683 bytes;
  SHA-256 `d524532faabdf4ad13a7835842345a3a6010176cabee9748a7cecc2d3de33961`.
- Installer artifact: `9994208323`, 10,654,930 bytes;
  SHA-256 `93a29ba578bcb0b52cfb80d68dba7be51dfa05abe113840f204129edab7f5d7b`.
- Tests cover denied/missing consent, same-size corrupted destination contents,
  source version changes after confirmation, conditional If-Match conflicts,
  token-free upload/download URLs, sequential upload chunk boundaries, lazy
  indexing, authentication and compact layouts. No 1 GiB real-account throughput
  or end-to-end native drag gesture acceptance is claimed by these CI tests.
- Google originals and source folder containers are retained. Native Google
  same-account copies preserve format and are explicitly not byte-verified.
- Main, Android, Store version and Partner Center remain outside this candidate.

## Previous read-only Windows candidate
- Exact code commit: bcb352194c61873b97c8f84e5f420738d46e898a
- Successful workflow run: 34047263513; job: 101524434622
- Portable ZIP artifact: FarooqDrive-Windows-x64; ID: 9993544705; bytes: 12696379
- Portable artifact SHA-256: 4d74c6376692b19e38987e14c688fedfbb490b2724f0c04102e4e85588542ff3
- Installer artifact: FarooqDrive-Windows-Installer; ID: 9993545045; bytes: 10603939
- Installer artifact SHA-256: fd4ba37a89bad9f1e25b5b834a599e826f127cb0c2be3f213e3deb2a239a0a0e
- Digests describe GitHub artifact archives, not the EXE inside them.
- Earlier auth test failure was traced to Flutter's default test HTTP override. A test binding now allows the real loopback callback; all Microsoft endpoints remain mocked. Corrected callback/security tests passed.
- No owner Microsoft account sign-in or device restart has been tested by the assistant. Follow ONEDRIVE-PRIVATE-WINDOWS-TEST.md on the owner's Windows PC.
- No Store submission, main merge, Android change or version-number change occurred.

## Microsoft read-only checkpoint
- Windows system-browser Authorization Code + PKCE with random state, exact loopback redirect, timeout/cleanup, account chooser and no client secret.
- Provider-specific secure-storage records, rotated refresh tokens, lazy renewal, disconnect cleanup and independent Google/Microsoft restoration.
- Microsoft client ID supplied via MICROSOFT_DESKTOP_CLIENT_ID from the existing repository Actions secret. Owner reports the secret saved; no value is committed in source.
- OneDrive root/folder paging, BFS indexing only on user request, quota, bounded retries and token-safe redirect downloads.
- Explicit private 32 MiB download cap until disk-backed transfer is implemented. This is a conservative test limit, not a provider limit.
- OneDrive mutation and cross-provider transfer endpoints throw read-only errors. No live OneDrive files have been changed by this work.
- All-provider Move/Cut-Paste is temporarily blocked before any transfer action until the new verification and final confirmation gate exists. This prevents the legacy automatic source cleanup during development.
- Windows Add account chooser and provider labels; Web remains on its existing Google authentication. Android branch remains unchanged.
- New mocked tests cover PKCE exchange, invalid state, secure restoration, rotated refresh tokens, disconnect, quota 401 renewal, paging-host rejection and download token separation.
- API consent and real Windows browser callback still need owner's test. Shared remote items, packages, cache transfers, final Move confirmation and public-release documentation remain later gates.
- Microsoft recommends supported authentication libraries. This Flutter implementation uses the handoff's explicit protocol approach with focused tests; no claim of Microsoft certification is made.

## Provider-routing checkpoint
- All controller API operations select the source or destination provider explicitly. Unknown providers fail instead of silently using Google.
- Account selection/addition, refresh and mutations no longer trigger global scans. Search and duplicate selection trigger scans explicitly.
- Invalidating the index clears cached files and folder sizes; duplicate results are not shown from an invalid index.
- Added regression tests for lazy scans, unsupported-provider handling, and mixed-provider copy routing without source Trash.
- Microsoft secret configuration is reported completed by the owner. Its value has not been read from GitHub and is not yet consumed by a login implementation.
- UI roots/labels, account restoration for Microsoft, per-account partial failures and transfer confirmation remain subsequent work.

## Milestone 1 checkpoint
- Added CloudDriveApi and shared exception/transfer types; GoogleDriveApi implements it and re-exports old type names for existing imports.
- Added provider metadata with Google defaults and preserved it through account updates; made item folder identity explicit.
- Added regression tests for legacy Google identity, Microsoft metadata, non-Google folders, and Google pagination through the shared API.
- Enabled only the existing Windows workflow on onedrive-foundation pushes for analyze/test/build feedback. Store and Web publishing workflows are unchanged.
- No new dependencies, Microsoft client ID literals, login behavior changes or transfer-cleanup behavior changes in this milestone.
- User supplied the Microsoft client ID in conversation; keep it in protected build configuration, not this source document.
- Screenshots confirm delegated Files.ReadWrite and User.Read, Mobile and desktop http://localhost, and Any Entra ID Tenant + Personal Microsoft accounts.
- Allow public client flows remains Disabled for the selected authorization-code flow with a registered native redirect. Live login has not been tested.
- Temporary cache, source verification and final Yes/No cleanup remain implementation requirements, NOT delivered capabilities.

## Baseline
- Feature branch: onedrive-foundation
- Exact starting commit: 485416a99feb8d12ba4c9ecf11b31f224b50ee27
- main and android-foundation were inspected and left unchanged.
- Existing Windows CI run 34028169234 at that exact commit succeeded, including Analyze, Test, Build Windows, portable packaging and installer.
- These are historical results inspected today, NOT a newly executed baseline run.
- Fresh feature-branch baseline run 34043545974 at a330c0bfb352836adc3602518c21b4ead5aeef55 passed Analyze, Test, Build Windows and packaging. Job 101514470222 was checked through GitHub.
- Flutter/Dart are not available in the current local runtime. New changes must pass feature-branch CI before the next implementation milestone.
- Do not publish, merge into main, change release versions, or submit to Partner Center without owner approval.
- Android remains separate at 1d0f708aa62f7d2f3aaf35bd8ca34810a0a8ea54. iOS follows Android later.

## Owner-approved mandatory safety requirements
These requirements supersede any older handoff allowing automatic source Trash after size verification.

1. Cut only selects items; it never removes the source.
2. Move and Cut/Paste use copy, verify, explicit final confirmation, then recoverable source Trash. This applies to drag-and-drop Move too.
3. No automatic source deletion, including same-account native Move shortcuts that bypass this gate. Copy-first moves may require extra cloud quota.
4. Verification must cover every file and folder, destination IDs, expected transferred byte lengths, and content integrity. Use compatible hashes where supported; otherwise a re-download and locally computed hash is a possible stronger verification route. If required verification cannot finish, preserve the source.
5. For native Google exports, verify exported bytes, not the original Google metadata size.
6. Recheck source versions and destination validity before cleanup. If the source changed, do not remove it based on stale verification. Use conditional operations where supported; block automatic cleanup where safety cannot be established.
7. Ask a final Yes/No question clearly identifying source, destination and verified items. Default to No. Closing, cancellation or app restart never implies Yes.
8. No retains both copies and reports Copy complete; source retained. Yes permits only the verified, unchanged source items to enter recoverable provider Trash/Recycle Bin.
9. Verification failure, interruption or uncertain state keeps the source. Partial cleanup failures must be reported accurately.
10. No permanent-delete feature is authorized. Do not promise mathematically absolute safety from a progress percentage or size-only checks.

## Windows transfer cache
- Use an application-owned, per-user disk cache, created on first need, not the installation directory.
- Expose the actual path, disk usage and free space in Settings; allow a user-selected alternative location with access validation.
- Use bounded memory buffers, streaming and resumable upload support for large transfers.
- Preflight local space and destination cloud quota; do not invent a maximum supported file size before tests.
- Transfer folder contents incrementally where practical.
- Clean verified completed temporary data safely; never delete active-transfer data.
- Interrupted transfers need explicit recovery/cleanup state. Resume is a planned capability until implemented and tested.
- Document local copies, retention/cleanup, bandwidth and space requirements in Help, Privacy, Terms and pre-transfer UI.
- Mobile size limits and background behavior require separate device testing. Same vendor across different accounts does not guarantee server-side transfer.

## Code findings to address after baseline
- GoogleDriveApi and GoogleAccountAuthorizer are directly coupled to DriveController.
- DriveItem.isFolder is Google MIME-derived; provider-neutral folder identification is needed.
- main still has full-index calls after addAccount, selectAccount, refresh and mutations. Startup-only laziness is not enough.
- Cross-account folder verification currently compares counts without verifying each transferred child; strengthen before permitting source cleanup.
- Existing byte-buffer APIs are unsuitable for claiming unrestricted large-file support.
- Prior repository search for drag-and-drop returned incomplete results. Inspect main.dart and platform code directly before asserting it is absent.

## Ordered implementation gates
0. Fresh baseline analyze/test and Windows build, no runtime changes.
1. Provider-neutral models/API and Google-only routing with backward-compatible account restoration.
2. Lazy user-triggered indexing and safe per-account failure handling.
3. Microsoft desktop public-client OAuth with PKCE/system browser, secure persistence, refresh and read-only browsing.
4. OneDrive writes, asynchronous copy monitoring, upload sessions, paging, retries and conflicts.
5. Disk-backed verified transfers and final user-confirmed source Trash state machine, including folder transfers.
6. Windows drag-and-drop: Explorer to app, internal multi-selection and app to Explorer. Verify native integration before promising readiness.
7. Mixed-provider regression, failure/cancellation/source-change tests, Help/Privacy/Terms, private Windows build.
8. Owner-approved version and exact Store candidate; only then Store submission.
9. Reconcile shared code with Android without overwriting its existing work; iOS later.

## Microsoft setup
Client ID is not needed for the first provider-neutral code milestones.
When authentication is ready, guide owner one screen at a time:
- Entra app registration named FarooqDrive, supporting organizational and personal Microsoft accounts.
- Windows Mobile and desktop platform with registered loopback redirect; match exact runtime redirect in code and token exchange.
- Delegated User.Read and Files.ReadWrite; runtime openid/profile/email/offline_access as needed.
- Public-client Authorization Code + PKCE, no client secret, no embedded password form.
- Official build configuration name: FAROOQDRIVE_MICROSOFT_CLIENT_ID; Dart define MICROSOFT_DESKTOP_CLIENT_ID.
- No passwords, refresh tokens, signing keys or user files in GitHub.
- If portal access requires tenant/account setup or billing, stop and ask owner; do not create paid resources.
- Partner Center app registration does not establish that Entra tenant access is configured.

Next action: verify Milestone 1 CI, then implement provider routing and lazy indexing before Microsoft OAuth.
