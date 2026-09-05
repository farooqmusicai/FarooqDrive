# Windows edition

## End user

1. `FarooqDrive-Setup-v19.0.0-Windows-x64.exe` چلائیں۔
2. installation مکمل ہونے کے بعد FarooqDrive کھولیں۔
3. **Add account** دبائیں اور browser میں Google account کی اجازت دیں۔
4. مزید accounts اسی طرح شامل کریں۔
5. بائیں طرف account یا **All Drives** منتخب کر کے files استعمال کریں۔

Installer موجودہ Windows user کے لیے install ہوتا ہے، Start Menu shortcut بناتا ہے،
اختیاری Desktop shortcut دیتا ہے اور Windows Settings سے صاف uninstall کیا جا سکتا ہے۔

## Builder

Requirements: Windows 10/11 x64، Flutter stable، Visual Studio with Desktop
development with C++، Inno Setup 6 اور Git۔

```powershell
cd apps/flutter
flutter pub get
flutter build windows --release
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" installer/FarooqDrive.iss
```

Installer `apps/flutter/release` میں بنے گا۔ Portable files
`apps/flutter/build/windows/x64/runner/Release` میں ملیں گی۔
Release سے پہلے صاف Windows 11 VM، non-admin account، install/uninstall، OAuth
callback، multiple accounts، بڑی upload، preview، download اور token refresh آزمائیں۔

Unsigned test installer پر Windows SmartScreen warning آ سکتی ہے۔ Production release
کے لیے code-signing certificate کو GitHub Secrets کے ذریعے استعمال کیا جائے گا؛ certificate
یا password repository میں کبھی شامل نہیں کیا جائے گا۔ Microsoft Store کے لیے reserved
identity، MSIX packaging، privacy URL، support URL، screenshots اور Partner Center
certification الگ حتمی release مرحلہ ہیں۔
