# Privacy

Private Windows OneDrive candidate: Microsoft refresh tokens are saved in secure
device storage. Cloud transfers also create unencrypted temporary file contents
under the Windows temporary directory, scoped to individual transfer jobs. Normal
completion/failure removes that job's files; crashes may leave them. Close the app
before manually clearing leftover job folders. File contents travel directly to
and from the selected Google/Microsoft services, including a destination download
for verification. See [transfer storage and limits](WINDOWS-VERIFIED-TRANSFERS.md).

Urdu version: [PRIVACY-URDU.md](PRIVACY-URDU.md)

FarooqDrive does not operate an intermediate file-storage service. Files are
transferred between the user's device/browser and Google Drive. The Windows
edition keeps configuration, encrypted tokens, and file index data locally. The
web edition keeps OAuth access tokens in page memory for the session.

FarooqDrive keeps a user-visible activity history on the current device/browser
for up to seven days. It may contain an action description, item details, account
email, and timestamp. Users can clear this history from the application. It is not
uploaded to a FarooqDrive-operated analytics or file-storage server.

Google Drive data is used only to provide user-requested file management,
navigation, search, storage reporting, duplicate detection, and transfer features.
FarooqDrive does not sell Google user data or use it for advertising.

Deployers are responsible for publishing a privacy policy naming themselves,
their contact details, their exact data use, retention, deletion procedure, and
Google API Services User Data Policy compliance.
