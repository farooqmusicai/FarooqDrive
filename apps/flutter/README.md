# FarooqDrive Flutter

This is the cross-platform FarooqDrive application. Web is the first reference
platform; Windows will use the same models, controller and Drive API service.

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

## Current milestone

- Multiple Google account connections during the active session
- Unified and per-account root views
- Complete paginated folder listing
- Breadcrumb navigation, search and sorting
- Create folder, upload, open and download
- Rename, move to Trash, copy, cut and paste
- Cross-account file copy/move through the user's browser

Recursive folder transfer, resumable large uploads, token recovery and the
settings/help surfaces remain on the Web completion checklist.
