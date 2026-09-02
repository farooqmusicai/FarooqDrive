# Google OAuth setup — Bring Your Own Credentials

FarooqDrive's public Windows application is credential-free. Each installation asks its owner to create a Google OAuth **Desktop app** client and enter that Client ID and Client Secret on first launch.

## In-app flow
1. Install and open FarooqDrive.
2. The first-run setup wizard appears automatically.
3. Create or select a Google Cloud project.
4. Enable **Google Drive API**.
5. Configure Google Auth Platform with an **External** audience.
6. In **Data Access**, add only:
   `https://www.googleapis.com/auth/drive.file`
7. In **Clients**, create a **Desktop app** OAuth client.
8. If the project is in Testing, add the Google account(s) you will use as test users.
9. Copy the Desktop Client ID and Client Secret into FarooqDrive.
10. FarooqDrive encrypts the credentials in its local application database.

## Testing versus production
Google states that External OAuth projects in **Testing** issue refresh tokens that expire after 7 days when scopes beyond basic identity are requested. FarooqDrive uses `drive.file`, so users who want stable long-term use should review Google's current publishing requirements for their own OAuth project.

`drive.file` is classified by Google as a non-sensitive Drive scope and is preferred over broad full-Drive scopes when it meets the application's needs.

## Security
Never commit OAuth credentials to GitHub. The official FarooqDrive source and Windows binaries do not contain the publisher's Client ID or Client Secret.
