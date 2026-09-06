# FarooqDrive: Windows-first OneDrive implementation

Status: Provider routing/lazy indexing passed all checks and Windows packaging in run 34046080811 at 98f4f9c0999492fbd3225a2e17e8b06727941259. Milestone 3 Windows OneDrive read-only integration is authored and awaiting CI and owner login testing.

## Microsoft read-only checkpoint
- Windows system-browser Authorization Code + PKCE with random state, exact loopback redirect, timeout/cleanup, account chooser and no client secret.
- Provider-specific secure-storage records, rotated refresh tokens, lazy renewal, disconnect cleanup and independent Google/Microsoft restoration.
- Microsoft client ID supplied via MICROSOFT_DESKTOP_CLIENT_ID from the existing repository Actions secret. Owner reports the secret saved; no value is committed in source.
- OneDrive root/folder paging, BFS indexing only on user request, quota, bounded retries and token-safe redirect downloads.
- Explicit private 32 MiB download cap until disk-backed transfer is implemented. This is a conservative test limit, not a provider limit.
- OneDrive mutation and cross-provider transfer endpoints throw read-only errors. No live OneDrive files have been changed by this work.
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
