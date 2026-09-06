# Web 21.1 update

The GitHub Pages source is the `web-update-21-1` branch. Pages deployments pin a tested commit from that branch; Windows and Store release sources are separate.

## Features

Google Drive and OneDrive accounts; expandable account/folder navigation; compact navigation/actions; eight Explorer-style views; Light/Dark; full account tooltips; shared remembered Name, Account, Size and Modified sorting; background scans with page progress and saved metadata indexes. Rescan all replaces the index. Name-and-size matches are candidates, not content-verified duplicates. Scans do not delete files.

Copy, Cut/Paste, upload and internal drag-and-drop use destination verification. Source cleanup is offered only after the batch passes verification and the owner confirms Yes. Conditional cleanup supports unchanged OneDrive source files; Google originals and original folder containers remain. No keeps both copies. Partial destination copies may remain after interruption.

## Browser differences

- Transfer/upload/download limit: **32 MiB per file**, with up to 10,000 items / 64 levels per batch. Windows transfers remain 1 GiB per file.
- Browser staging uses memory, potentially several buffers. No Windows cache folder is created by the web app. Keep the tab open; no restart resume.
- Microsoft credentials use MSAL's memory cache. Reconnect accounts after a full page reload. Preferences, scan metadata and local activity may persist as browser site data. No tokens or file content are included in the index.
- Popups, browser CORS restrictions and organization consent rules can affect authentication and transfers. A blocked or failed verification never authorizes source removal.
- No fixed account count is imposed. Quotas, consent, browser resources and provider throttling apply. Do not claim unlimited tested accounts.
- Internal dragging is supported. This is not a mounted Windows drive or a full OS clipboard/Explorer integration.
- Android, iPhone/iPad and macOS apps: coming soon.

## Microsoft Entra setup

In the existing FarooqDrive app registration, add Authentication → **Single-page application** → redirect URI:

`https://farooqmusicai.github.io/FarooqDrive/microsoft-callback.html`

Keep the Windows Mobile and desktop `http://localhost` redirect. Use delegated `User.Read` and `Files.ReadWrite`; do not add a client secret to the browser app. The build receives the public app ID through `MICROSOFT_WEB_CLIENT_ID`, using the existing GitHub `FAROOQDRIVE_MICROSOFT_CLIENT_ID` secret. The account audience is organizational and personal Microsoft accounts. The Microsoft branding URLs do not constitute publisher verification; a verified custom domain and applicable Partner Center steps are a separate owner task.

The callback is a standalone, same-origin MSAL redirect bridge. Do not load Flutter on it or add a Cross-Origin-Opener-Policy header that severs popup communication. MSAL is bundled locally with its MIT license. Dependencies and integrity hashes are pinned in web-auth/package-lock.json. Never paste access tokens or callback query strings into support reports.

## Google setup

Keep the existing web OAuth client (`FAROOQDRIVE_WEB_CLIENT_ID`) and authorized JavaScript origin `https://farooqmusicai.github.io`. No new Google scope is introduced by this update. Existing consent, publishing and verification requirements continue to apply. Update public consent branding/support/privacy URLs to match the published website if they differ.

## Release acceptance

CI builds the Microsoft bundle, tests account isolation/error redaction, analyzes Dart, runs Flutter tests (including transfer/index safety), and compiles the web app. Live owner acceptance must include login to Google and OneDrive, folder browsing, a small local upload and verified copy, and Move with No before testing Yes on disposable OneDrive files. A successful build alone does not prove tenant consent or live cloud transfer success.
