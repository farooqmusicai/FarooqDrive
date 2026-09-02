# Microsoft Store Release Worksheet

## Items you must obtain from Partner Center
These are assigned to your developer account/application and cannot be invented in source code:
- Reserved product name
- Package/identity name
- Publisher ID / publisher distinguished name where applicable
- Publisher display name

## Store listing material
Use the copy in `store/STORE_LISTING_EN-US.md` as the starting English listing. Replace support/privacy URL placeholders before submission. Upload final screenshots that show the real released UI and do not expose personal account details.

## Privacy
Because FarooqDrive accesses Google account information and user file metadata/content under user authorization, provide a public privacy-policy URL in Partner Center. `PRIVACY.md` is the draft source for that web page.

## Package
Preferred target: MSIX, x64, Windows 11 primary. Keep Windows 10 compatibility only if final testing confirms it. Microsoft Store signs Store-submitted MSIX packages as part of publishing; direct web distribution should use a trusted signing certificate.

## Certification preflight
- App launches without developer tools.
- No external runtime/database installer is required.
- Google login uses the system browser.
- Privacy policy link works publicly.
- Support contact works.
- All Store images are final and correctly sized.
- No secrets are present in source control.
- Installer/package does not bundle unrelated software.
- Test install, update and uninstall on a clean Windows 11 machine.


## FarooqDrive 0.9.3 OAuth note
The Store package is credential-free. Do not embed a publisher Google Client ID or Client Secret. On first launch, each user configures their own Google OAuth Desktop client inside FarooqDrive.
