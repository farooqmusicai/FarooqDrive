# Web edition

The web edition is static and stores no files on a FarooqDrive server. Browser
requests go directly to Google APIs.

## Deploy

Upload the contents of `dist/` to any HTTPS static host. Open Settings, paste
your own Google Web OAuth Client ID, save, and connect an account.

The Client ID is public configuration, not a password. Never place a Client
Secret in HTML, JavaScript, environment variables exposed to the browser, or the
repository.

## Limitations

- Google authorization must match the exact deployed origin.
- Tokens remain in memory and accounts must be reconnected after page reload.
- Browser memory and provider limits make very large cross-account copies better
  suited to the Windows edition.
- Google-native Docs/Sheets/Slides are opened through their Drive web links and
  cannot be downloaded as ordinary binary files without choosing an export format.
