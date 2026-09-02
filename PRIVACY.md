# FarooqDrive Privacy Policy

**Effective date:** 2 September 2026  
**Publisher:** Mohammad Farooq / FarooqDrive

> Release note: Replace the support email, website and legal address placeholders below before public distribution.

## 1. What FarooqDrive is
FarooqDrive is a desktop application that lets a user connect Google Drive accounts that the user controls or is authorized to use, view combined storage information, and manage files that FarooqDrive creates or has been granted access to.

## 2. Information FarooqDrive accesses
When you authorize Google, FarooqDrive may access your Google account identifier, email address, display name, profile image, Google Drive storage quota information, and Drive file/folder metadata and content permitted by the Google OAuth grant. FarooqDrive requests the full `https://www.googleapis.com/auth/drive` scope so its multi-account storage layer can discover and synchronize files placed manually in each connected account's `Farooqdrive` folder and perform supported read/write operations. Google classifies this as a restricted scope.

## 3. Where information is stored
The standard desktop edition stores application metadata locally on your Windows computer in its application data directory. OAuth refresh tokens are encrypted before local storage. File bytes are not permanently stored in FarooqDrive's local database: uploads are sent to Google Drive and downloads/previews are streamed on demand.

## 4. Data sent to third parties
FarooqDrive communicates with Google services when you sign in, authorize an account, request quota information, upload, preview, download, rename, sync, or trash a Drive file. Google processes that data under Google's own terms and privacy policies. The standard open-source desktop edition does not operate a FarooqDrive cloud server for your file contents.

## 5. Analytics and advertising
The standard release described by this policy does not include advertising, behavioral profiling, sale of personal information, or third-party analytics. If a future release adds telemetry or cloud services, this policy must be updated before that release is distributed.

## 6. Security
FarooqDrive binds its local service to the loopback interface only, uses encrypted storage for OAuth refresh tokens, uses random OAuth state values, and uses Google OAuth instead of asking users for Google passwords. Users should keep Windows, FarooqDrive, and their Google account security settings up to date.

## 7. User controls
You can disconnect a Google Drive account from FarooqDrive. Disconnecting removes its local FarooqDrive connection; it does not automatically delete your files from Google Drive. You may also revoke FarooqDrive's Google access from your Google Account security settings. Uninstalling FarooqDrive does not delete files stored in Google Drive.

## 8. Retention and deletion
Local metadata remains on the device until it is removed through application functionality or the application's local data is deleted. Google Drive content remains subject to the user's Google Drive account and actions.

## 9. Children
FarooqDrive is not intentionally designed to collect children's personal information. Public distribution must comply with applicable age and child-privacy requirements in the markets where the app is offered.

## 10. Changes
Material changes to this policy will be reflected by updating the effective date and publishing the current policy with the app and/or on the FarooqDrive website.

## 11. Contact
Support email: **[ADD SUPPORT EMAIL]**  
Privacy contact: **[ADD PRIVACY EMAIL]**  
Website: **[ADD FAROOQDRIVE WEBSITE URL]**

## User-supplied Google OAuth credentials
The public FarooqDrive Windows build does not include a publisher-owned Google OAuth Client ID or Client Secret. Each installation may store the user's own Google OAuth Desktop Client ID and Client Secret in encrypted local application storage. These credentials are used only to authorize that installation with Google and are not intentionally transmitted to a FarooqDrive-operated server.

## Intended Drive usage boundary
Although the Google `drive` OAuth grant is broad, FarooqDrive's product design is to use the `Farooqdrive` storage folder(s) associated with the user's connected accounts for its unified storage operations. Users should understand that the OAuth permission itself authorizes wider Drive access.
