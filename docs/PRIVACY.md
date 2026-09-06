# FarooqDrive Privacy Policy

Updated: 6 September 2026. Publisher: Mohammad Farooq. Contact: support@mymandoob.com.

This policy describes FarooqDrive 21.1 for Windows with Google Drive and Microsoft OneDrive. Existing web and mobile editions may provide fewer features; OneDrive described here is Windows functionality. FarooqDrive is an independent client, not a Google or Microsoft service.

## Information used and purpose

With your permission, FarooqDrive accesses your account identity (name/email), authorization tokens, storage quota, and file/folder metadata such as names, IDs, parent folders, sizes and modified dates. It uses these to connect accounts, browse, search, identify possible duplicates and carry out file actions you request. File contents are accessed for requested upload/download/copy/export and transfer verification. Duplicate scans compare metadata, not file contents.

Your files travel directly between your device and the selected Google/Microsoft services. FarooqDrive does not operate an intermediate file-storage or analytics server. Providers receive the network requests needed to deliver their services and handle data according to their own policies. FarooqDrive does not sell account or file data or use it for advertising. FarooqDrive's use and transfer of information received from Google APIs will adhere to the Google API Services User Data Policy, including its Limited Use requirements. Provider account permissions and organization policies still apply.

## Data on your Windows device

- Google and Microsoft authorization credentials are stored using the platform secure-storage mechanism. Passwords are entered with the provider in your browser, not collected in the FarooqDrive interface.
- Account configuration, appearance and sort preferences are retained locally. Active file listings are used in memory.
- A scan index is saved locally until replaced by a successful Rescan. It contains file/folder metadata, account identifiers/emails, paths, duplicate classifications, totals and scan time. It contains no file contents or OAuth tokens. This metadata cache is not encrypted by FarooqDrive. Results may become outdated; refreshing a folder does not replace this index. Disconnecting an account removes that account's cached items from the saved index.
- Activity history is local, may include names, paths, account emails, action descriptions and timestamps, and is limited to 400 entries. Entries older than seven days are filtered when history is loaded or recorded; this is not an automatic background deletion timer while the app is closed. Clear History removes saved activity.
- Windows diagnostics can be written locally to `%LOCALAPPDATA%\FarooqDrive\farooqdrive-crash.log`. This separate troubleshooting log has no automatic seven-day retention rule. It is not automatically sent to the publisher. Review any log before choosing to send it to support.

## Temporary transfer contents

Windows cloud transfers and file-picker uploads stage file contents under the Windows temporary directory in `FarooqDrive-transfers` job folders. FarooqDrive does not encrypt these temporary contents. Keep sufficient disk space for the file being processed plus normal operating-system needs. Normal completion or failure removes the job's temporary files; a crash or forced shutdown may leave them. Close FarooqDrive before manually removing leftover job folders. Uninstalling alone should not be assumed to remove all temporary files, secure credentials or diagnostic files.

Destination verification downloads contents again and uses SHA-256 for eligible transfers. This consumes additional bandwidth. Providers can retain successfully uploaded or partial copies after interruptions according to their service behavior. Automatic resume after app restart is not provided.

## Your choices and deletion

You choose which accounts to connect and which operations to request. Disconnect accounts in FarooqDrive to remove their saved connection credentials and indexed items from this app; disconnecting does not delete your cloud files and does not necessarily revoke provider-side consent. You can also revoke access in your Google or Microsoft account's connected-app permissions. Organization administrators may control work/school consent. Clear activity separately; remove local diagnostic and leftover temporary files as described above. Replacing a scan refreshes the cached metadata; local app data can also be removed when retiring the installation after disconnecting accounts.

A Move request copies and verifies eligible contents before asking separately about source cleanup. Only eligible unchanged OneDrive source files are conditionally moved to the source Recycle Bin after Yes. Google originals and original folder containers remain where safe conditional cleanup is unavailable. No retains both copies. Explicit Trash is a separate requested operation.

## Web edition, support and changes

The web edition uses browser/session OAuth behavior and available local browser storage; its provider features and transfer limits differ from Windows. This Windows update does not enable OneDrive on web/mobile. If you contact support, the information you choose to send is used to respond and investigate your request; do not send passwords or tokens.

Policy changes will be dated here and reflected on the public policy page for the corresponding release. Contact support@mymandoob.com with questions or requests concerning data you have sent directly to the publisher.
