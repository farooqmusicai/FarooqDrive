# FarooqDrive 21.1 — How it works on Windows

## Connect and browse

Choose Add account, select Google Drive or Microsoft OneDrive, and approve access in the system browser. Repeat for other accounts. Personal and permitted work/school OneDrive accounts are supported when provisioned; organization policy may require an administrator. There is no fixed account-count cap in FarooqDrive, but quotas, service throttling and device resources apply.

Select an account to open its root. Expand sidebar arrows to browse folders and subfolders on demand. Double-click folders, use breadcrumbs or Back/Up, and pin the sidebar when needed. All Drives combines account listings and provider-reported storage; it does not create a new pooled physical disk. Full-text searches here mean searching metadata such as names and paths, not the contents of documents.

## Appearance and sorting

Use the sun/moon button beside History for Light/Dark mode. The app follows system appearance until you choose; your choice is saved locally. View beside the sort menu provides Extra large icons, Large icons, Medium icons, Small icons, List, Details, Tiles and Content.

In Details, click Name, Account, Size or Modified. First choosing a column gives ascending order (A–Z, smaller first, older first); click again for descending. The active arrow shows direction. Folders stay first and unknown sizes/dates sort before known values in ascending order. The chosen column/direction applies across all tabs and is saved for the next launch. Resize column edges by dragging.

## Scan index and duplicates

Scan all builds one metadata index for connected accounts. The first duplicate scan or first global search can also start it. Scanning does not lock navigation or file operations. A small status message shows progress/completion; finishing never pulls you away from the folder you opened meanwhile.

The index, scan time, duplicate classifications and folder totals are saved locally. Switching tabs, reopening the app or ordinary Refresh does not discard it. Select the duplicate-results tabs to inspect saved results. Press Rescan all to refresh the index; the previous snapshot remains available until a complete new scan succeeds. An error or a file/account change during scanning prevents publishing an inconsistent replacement. Local mutations mark the previous results outdated; cloud-side edits made elsewhere are not continuously detected. Restored results are therefore labelled as a saved snapshot. Disconnect removes that account's cached metadata. The index contains metadata, not file contents or tokens, and is not encrypted by the app.

Exact duplicates currently means equal normalized names and known reported sizes. It does not prove byte-for-byte equality and can include matches within one account. Same-name results flag different or unknown sizes. Neither scan automatically deletes anything. Review source locations before any action.

## File operations

Select one or more items, use Copy or Cut, open the destination and Paste. Cut alone does not delete. Internal drag-and-drop offers Copy/Move onto account/folder targets, breadcrumbs or blank space in the current folder. It is internal FarooqDrive dragging, not native Windows Explorer drag-in/drag-out. Use Upload to pick files from your PC. New folder, Rename, Download and explicit Trash are also available subject to permissions. Consult red ⓘ for transfer details/errors and History for recorded outcomes.

## Verified transfer and Move behavior

For supported file transfers the app stages contents in a temporary disk file, uploads them and downloads the destination again for SHA-256 verification. Eligible Move then asks separately whether to remove source originals. No/dismiss retains both copies. Only eligible unchanged OneDrive source files can be conditionally sent to their source Recycle Bin after Yes; source and destination versions are rechecked. Google original files and original folder containers remain when this safe conditional cleanup is unavailable. The outcome explains retained sources. A successful copy is not a guarantee that all Move originals were removed.

Same-account Google-native copies preserve native format and keep originals. Between accounts/providers, supported Google documents export to Office formats or PNG; export is not guaranteed to preserve all provider metadata, versions or features. Explicit Trash has its own confirmation and does not perform the Move verification sequence.

## Limits and temporary storage

- Transfers: 1 GiB per file, 10,000 items and 64 folder levels per batch.
- Windows Upload uses a file-picker stream and disk staging; local originals remain.
- OneDrive Download-to-PC: 32 MiB; download still uses memory.
- Keep enough temporary disk space for the largest file being processed plus normal Windows needs. Transfers use internet bandwidth including verification downloads.
- Cache is under Windows Temp / FarooqDrive-transfers / job folders. It is not encrypted by FarooqDrive. Normal job completion/failure cleans its files. After a crash, close the app before manually removing leftovers.
- No automatic resume after restarting. Interrupted jobs may leave destination copies; retries can create additional copies. Do not assume the app performs continuous background sync or direct server-to-server transfer between all accounts of the same vendor.

## Privacy, history and support

Tokens use Windows secure storage. Scan metadata, settings and local history remain on this device; file traffic goes directly to selected providers. History shows up to 400 entries with a seven-day filter applied when loaded/recorded; Clear History removes it. Local crash diagnostics are separate from activity history. See Privacy for retention and removal details.

Help is available inside the app in English and Urdu. Support: support@mymandoob.com. Published web/mobile features can differ; OneDrive in this document describes Windows.
