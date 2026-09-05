# FarooqDrive Flutter

This is the cross-platform FarooqDrive application. Web and Windows share the
same interface, controller, models, and Google Drive API service.

## Run locally

```sh
flutter pub get
flutter run -d chrome \
  --dart-define=GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

The Web OAuth client must include the running site's origin in **Authorized
JavaScript origins**. Never put a Google Client Secret in this application.

## Build Web

```sh
flutter build web --release \
  --dart-define=GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

## Run or build Windows

Create a Google OAuth **Desktop app** client, then run:

```sh
flutter create --platforms=windows .
flutter run -d windows \
  --dart-define=GOOGLE_DESKTOP_CLIENT_ID=YOUR_DESKTOP_CLIENT_ID.apps.googleusercontent.com
```

The Desktop Client ID and matching Desktop Client Secret can instead be entered
in FarooqDrive Settings. They are never committed to the public repository;
the secret and refresh tokens are stored in the operating system's secure
credential storage. The app uses the system browser, a loopback callback, and
PKCE, and connected accounts can be restored on restart.

## Current milestone

- Multiple Google account connections, including secure Windows restoration
- Unified and per-account root views
- Complete paginated folder listing
- Breadcrumb navigation, search and sorting
- Create folder, upload, open and download
- Rename, move to Trash, copy, cut and paste
- Cross-account file copy/move through the user's browser

The GitHub Windows workflow produces a portable x64 ZIP. A signed installer,
resumable large transfers, and clean-machine Windows 10/11 testing remain on
the Windows release checklist.
