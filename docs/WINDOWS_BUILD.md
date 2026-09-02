# Windows Build and Distribution

## End-user objective
The final public user should receive an installer or Store installation and should not install Docker, Node.js or MySQL.

## Direct-download build
The GitHub Actions workflow `.github/workflows/windows-release.yml` builds on a Microsoft-hosted Windows runner. It produces an NSIS setup EXE and a portable EXE. For a professional direct download, add a trusted Windows code-signing certificate through secure GitHub Actions secrets.

## Signing secrets
`CSC_LINK` may contain a secure certificate reference/data supported by electron-builder and `CSC_KEY_PASSWORD` contains its password. Never commit a PFX/P12 or its password.

## Microsoft Store
Microsoft currently recommends MSIX for new Win32/Electron Store distribution, while also allowing traditional EXE/MSI listing paths. For the preferred MSIX path, first reserve **FarooqDrive** in Partner Center, then obtain the Store package identity/publisher values. Those values cannot be finalized before Partner Center assigns them.

After Store identity and final icon assets exist, package the Windows app layout as MSIX using Microsoft's current Electron/WinApp packaging guidance and test with Windows App Certification Kit before submission.

Official references used when this guide was prepared:
- https://learn.microsoft.com/windows/apps/distribute-through-store/how-to-distribute-your-win32-app-through-microsoft-store
- https://learn.microsoft.com/windows/apps/dev-tools/winapp-cli/guides/electron-packaging
- https://learn.microsoft.com/windows/apps/publish/get-started
