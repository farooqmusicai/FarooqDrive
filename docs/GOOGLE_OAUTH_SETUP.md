# Google OAuth setup — Bring Your Own Credentials

FarooqDrive's public Windows application is credential-free. Each installation asks its owner to create a Google OAuth **Desktop app** client and enter that Client ID and Client Secret on first launch.

## Why FarooqDrive requests full Google Drive access
FarooqDrive's core purpose is to combine multiple Google Drive accounts into one virtual storage dashboard. It creates/uses a `Farooqdrive` root folder in each connected account, aggregates quota, routes uploads, syncs files placed manually in those folders, and supports preview/download/rename/move/delete operations. For that unified sync/file-manager behavior FarooqDrive requests:

`https://www.googleapis.com/auth/drive`

Google classifies this as a **restricted** scope because it can see, edit, create and delete all files in the authorized Drive account. FarooqDrive is designed to operate on its managed `Farooqdrive` storage layer, but the OAuth grant itself is broader.

## Setup
1. Install and open FarooqDrive.
2. The first-run setup wizard appears automatically.
3. Create or select a Google Cloud project.
4. Enable **Google Drive API**.
5. Configure Google Auth Platform with an **External** audience.
6. In **Data Access**, add `https://www.googleapis.com/auth/drive`.
7. In **Clients**, create a **Desktop app** OAuth client.
8. If the project is in **Testing**, add every Google account that you intend to connect as a Test User.
9. Copy the Desktop Client ID and Client Secret into FarooqDrive.
10. FarooqDrive encrypts these OAuth client values in local application storage.
11. Connect each Google Drive account from FarooqDrive.

## Testing and production
Google's rules for restricted scopes can require OAuth verification and, depending on how data is handled, additional security review for wider production use. The BYOC edition does not hide or bypass those requirements: each user controls the Google Cloud project whose OAuth credentials they put into FarooqDrive.

## Security
Never commit OAuth credentials to GitHub. The official FarooqDrive source and credential-free Windows binaries contain no publisher Google Client ID or Client Secret.
