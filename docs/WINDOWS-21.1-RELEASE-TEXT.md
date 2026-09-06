# FarooqDrive 21.1 — Windows listing and console preparation

Prepared 6 September 2026. Text below describes the Windows OneDrive branch, not the currently published Google-only web/mobile editions. Publish this listing together with the matching accepted Store package, not ahead of it. The displayed version stays 21.1. This change does not submit an MSIX or change the Store identity.

## Microsoft Store — description (English, ready to paste)

Bring your Google Drive and Microsoft OneDrive accounts together in FarooqDrive, a Windows cloud file manager with a familiar Explorer-style interface.

Connect multiple accounts, browse folders from the expandable sidebar, and view each account's reported capacity, usage and free space. Switch between eight layouts: Extra large icons, Large icons, Medium icons, Small icons, List, Details, Tiles and Content. Choose Light or Dark mode, with your preference remembered on your device.

Sort files by Name, Account, Size or Modified date. Click a column again to reverse its order. Manage files with New folder, Upload, Download, Copy, Cut, Paste, Rename and Trash, or drag items between folders inside FarooqDrive. Search and duplicate scans build an index in the background so you can continue browsing while the scan runs. Scan results are saved on your device across tabs and restarts until you press Rescan all; ordinary Refresh does not clear them. Sorting is shared across tabs and remembered. Saved results can be outdated after cloud changes. Duplicate suggestions compare names and reported sizes; they do not certify identical file contents and never delete files automatically.

Windows file-picker uploads and supported cloud transfers use local temporary disk storage. Transferred destination contents are downloaded again for SHA-256 verification. Move operations retain the source until verification and a separate final confirmation. Eligible unchanged OneDrive source files can then go to their Recycle Bin. Google source files and original folder containers remain where safe conditional cleanup is unavailable; the app reports these retained originals. Choosing No keeps both copies.

Current transfer limits are 1 GiB per file, 10,000 items and 64 folder levels per batch. Download-to-PC from OneDrive is limited to 32 MiB. Transfers consume local disk space and internet bandwidth, including verification downloads. The app does not encrypt its temporary file contents. Interrupted operations may leave destination copies or temporary job files; automatic resume after app restart is not supported. Google-native documents may require export when transferring between accounts.

FarooqDrive transfers files directly between your device and your chosen cloud services. It does not provide a separate cloud-storage subscription or intermediate file-storage server. Account access, available space, organization policies and service limits still apply. There is no fixed app-imposed account-count cap.

Includes English and Urdu Help, a red transfer-information button and local activity history. Windows Explorer integration, a mounted virtual drive, continuous folder synchronization and native desktop drag-in/drag-out are not included in this release; use Upload to select local files.

Google and Microsoft accounts and an internet connection are required for their respective services. FarooqDrive is an independent application and is not affiliated with or endorsed by Google or Microsoft.

Support: support@mymandoob.com
Website: https://www.mymandoob.com/farooqdrive/

## Short description

Manage Google Drive and OneDrive accounts together with Explorer-style views, verified transfers and Light/Dark mode.

## Features (separate Store fields)

- Multiple Google Drive and Microsoft OneDrive accounts
- Expandable account and folder navigation
- Eight Explorer-style file views
- Saved Light and Dark appearance
- Reversible Name, Account, Size and Modified sorting
- Background search indexing and duplicate suggestions
- Copy, Cut, Paste and internal drag-and-drop
- Destination verification and final confirmation for eligible Move cleanup
- Provider-reported storage, local history and bilingual Help

## What's new

Added Microsoft OneDrive support on Windows, compact navigation and action controls, eight file views, saved Light/Dark mode, clickable sorting columns, background duplicate scans and expanded English/Urdu Help. Improved local file uploads and internal drag-and-drop. Version display remains 21.1; the Test label has been removed.

## Certification notes (not public marketing)

Use legitimate Google and/or Microsoft test accounts with OneDrive provisioned. Add account opens the system browser. The app uses delegated user access, never tenant-wide application permissions. Approve requested access and return to the app. Review the transfer information button and Help before test transfers. Confirm small local uploads and provider-pair copies; verify that No at final Move cleanup leaves originals. Google originals/folder containers intentionally remain. No hidden purchase or developer-operated file-storage server is required. Record the exact accepted commit and installable MSIX build separately before submission. The EXE test installer is not the Store MSIX.

## Microsoft / Google / website actions

No new scopes or OAuth client credentials are required for the appearance, sorting or scan changes in this update.

1. Microsoft Entra: retain the working desktop registration, localhost redirect and supported work/school plus personal accounts. Current requested delegated access: User.Read and Files.ReadWrite, plus OpenID identity/offline-access scopes. Set or verify Home page, Privacy statement and Terms URLs in Branding & properties after the pages are live. Review publisher-domain/publisher verification for public organization-account adoption; organizational consent policies may require an administrator. Store publisher registration is separate from Entra publisher verification. Do not add Files.ReadWrite.All or application permissions for these UI changes.
2. Google Auth Platform: current desktop code requests the full drive scope, plus identity scopes. Full drive is restricted. Check Audience/Publishing status and Verification Center for production approval, authorized domains and a matching public homepage/privacy link. Changes to branding or scopes can require review. Native device-only data access may qualify for a security-assessment exception, but do not assume verification is waived or that approval is already present. No new scope is introduced here.
3. Microsoft Partner Center: update description, features, release notes, support/privacy links and screenshots showing both themes and both providers with test data. Review privacy declarations against the actual local data use. Test the matching MSIX before submitting once. Display version 21.1 can remain stable; the eventual MSIX package identity/version must still meet Store update rules and allow existing users to receive the update. Inspect the currently published package before selecting that number.
4. Website: use the repository Privacy, Terms and Help text for the matching Windows release. Keep existing web/mobile availability clearly identified. Publish legal pages before pointing console links to them. This repository change does not deploy mymandoob.com; hosting access/source is needed for that separate publication.

Sources checked 6 September 2026:
- https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification
- https://developers.google.com/identity/protocols/oauth2/production-readiness/brand-verification
- https://learn.microsoft.com/en-us/entra/identity-platform/publisher-verification-overview
- https://learn.microsoft.com/en-us/entra/identity-platform/howto-configure-publisher-domain
- https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/app-package-requirements
- https://learn.microsoft.com/en-us/windows/apps/publish/store-policies
