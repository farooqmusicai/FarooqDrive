# FarooqDrive for Windows

Urdu version: [WINDOWS-GUIDE-URDU.md](WINDOWS-GUIDE-URDU.md)

## End user

1. Run `FarooqDrive-Setup-v20.0.0-Windows-x64.exe`.
2. Open FarooqDrive when installation finishes.
3. Select **Add Google account** and approve access in the browser.
4. Repeat the process to connect additional accounts.
5. Select an account or **All Drives** in the sidebar to manage files.

The installer installs FarooqDrive for the current Windows user, creates a Start
Menu shortcut, offers an optional desktop shortcut, and supports clean removal
through Windows Settings.

## Builder

Requirements: Windows 10/11 x64, Flutter stable, Visual Studio with Desktop
development with C++, Inno Setup 6, and Git.

```powershell
cd apps/flutter
flutter pub get
flutter build windows --release
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" installer/FarooqDrive.iss
```

The installer is written to `apps/flutter/release`. Portable application files
are written to `apps/flutter/build/windows/x64/runner/Release`.

Before release, test clean Windows 10 and 11 computers, a non-administrator
account, install/uninstall, OAuth callback, multiple accounts, large uploads,
preview, download, and token refresh.

An unsigned test installer may trigger Windows SmartScreen. Production signing
will use a code-signing certificate through GitHub Secrets. Never commit the
certificate or password to the repository.
