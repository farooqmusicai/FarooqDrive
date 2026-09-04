# Troubleshooting

## Error 400 / redirect or origin mismatch
Use a Web OAuth client for web, a Desktop client for Windows, and copy the exact
HTTPS origin into Authorized JavaScript origins.

## Access blocked / app in testing
Add the Google email under Google Auth Platform > Audience > Test users.

## Second account opens the first account
Sign into both accounts in the browser and use the account chooser. Disconnect,
then add again if Google reused an active session.

## Preview does not open
Some file types have no browser preview. Download the file; Google-native files
open through their `webViewLink`.

## Sync or list is incomplete
Confirm Drive API is enabled, reconnect to refresh scope, clear search, and check
whether the item is in My Drive rather than a Shared Drive.

## Security recovery
Revoke FarooqDrive in Google Account security, replace the OAuth credential if
it was exposed, and remove any leaked credential from Git history before release.
