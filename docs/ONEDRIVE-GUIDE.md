# OneDrive in FarooqDrive 21.1

FarooqDrive brings authorized Google Drive and Microsoft OneDrive accounts into one explorer interface. Your cloud storage stays with the provider.

## Connect and browse

1. Open FarooqDrive and select **Add account → Microsoft OneDrive**.
2. Sign in on Microsoft's page and approve the requested delegated access.
3. Select the account in the left panel. Expand its arrow to browse folders; double-click a folder in the file list to open it.
4. Use Back, Up or breadcrumbs to navigate. All Drives combines connected accounts.
5. Hover over an account to see its full name and email. Quota cards show provider-reported storage, not a new storage allocation from FarooqDrive.

Repeat Add account for other accounts. FarooqDrive imposes no fixed account count; device resources, provider quotas and organizational policies apply. The configured sign-in audience includes personal and work/school accounts, but an organization can require administrator consent or restrict access.

## Explorer tools

Light/Dark mode is saved on the device. Eight views are available: Extra large, Large, Medium and Small icons, List, Details, Tiles and Content. Click Name, Account, Size or Modified to sort; click again to reverse. Sorting is remembered across tabs. Folders remain first.

Use Upload, Download, New folder, Rename, Copy/Cut and Paste in the toolbar. Open the destination account/folder before pasting. Internal drag-and-drop uses the same transfer mechanism. This is not a mounted Windows drive or full operating-system clipboard integration.

## Copy and Move safety

Files pass through your device; FarooqDrive does not operate an intermediate file-storage server. Transferred content is uploaded and downloaded again for SHA-256 verification. Cross-provider transfers therefore use additional internet traffic.

Move/Cut does not delete an original at the beginning. After the whole batch is verified, a final Yes/No prompt controls eligible source cleanup:

- **No or dismissal:** keep both copies.
- **Yes:** only unchanged OneDrive source files are eligible for conditional Recycle Bin cleanup.
- **Google source files and original folder containers remain.**
- Failed verification or interruption does not authorize source cleanup. Partial or completed destination copies may remain; check Activity before retrying.

Google-native same-account copies preserve their format and keep originals; supported cross-account exports use Office formats or PNG. Copying does not promise to preserve sharing permissions or version history.

## Current limits

| Item | Windows | Browser |
| --- | --- | --- |
| Transfer/upload file limit | 1 GiB | 32 MiB |
| Batch | 10,000 items, 64 folder levels | 10,000 items, 64 folder levels |
| OneDrive download-to-device | 32 MiB | 32 MiB |
| Staging | Temporary disk file | Temporary browser memory |
| Restart resume | Unavailable | Unavailable; keep the tab open |

Windows staging is not encrypted by FarooqDrive. Completed/failed jobs clean up their own temporary files; a crash may leave job folders. Close the app before manually clearing leftovers at the location shown in Help. The browser does not create that Windows transfer-cache folder; it can need multiple memory buffers per file.

## Scans and saved results

Scan all builds a metadata index across connected accounts. Duplicate scans run in the background while you browse. Results remain until Rescan all refreshes them; mutations mark old results stale. Provider failures keep the previous index and show the failing stage/account.

Matching name and known size identifies duplicate candidates, not proven identical content. Same-name results flag different or unknown sizes. Scans never delete files. Large or throttled accounts can take longer; repeated clicks do not start parallel scans.

## Sign-in and privacy

The web version uses Microsoft MSAL with temporary in-memory credentials. Reconnect after a full reload. Saved scan indexes contain metadata, not file contents or OAuth tokens. Preferences and local activity may also remain in browser site data. Disconnect accounts and clear site data on shared computers.

Windows uses secure local token storage. Disconnect removes the app connection; it does not delete the cloud account. Provider-side consent can be managed through the provider's own account controls.

The published web owner confirmed OneDrive login, folder listing and storage display on 6 September 2026. Live transfer acceptance is separate: use a disposable small file and try Move with No first.

## Setup for developers

See [Web setup](WEB-21.1-UPDATE.md) for the existing SPA callback, build configuration and deployment. Windows uses the desktop localhost redirect. Delegated access uses User.Read and Files.ReadWrite. Never embed a client secret in browser code or commit tokens.

Publisher verification is separate from Microsoft branding URLs. Google OAuth verification and tenant consent remain provider requirements. This project does not imply endorsement by Google or Microsoft.

## Support and platforms

[Support](https://www.mymandoob.com/farooqdrive/support.html) · [Privacy](https://www.mymandoob.com/farooqdrive/privacy.html) · [Terms](https://www.mymandoob.com/farooqdrive/terms.html)

For a problem, report the platform, version, provider, operation and sanitized Activity error. Do not send passwords, tokens or sign-in callback URLs containing a code.

Version remains **21.1**. Android, iPhone/iPad and macOS apps are **coming soon**. A repository update does not mean a new Microsoft Store package has been submitted.
