# Windows edition

## End user

1. Installer یا Portable EXE چلائیں۔
2. اپنی Google Desktop OAuth Client ID/Secret درج کریں۔
3. **Add account** دبائیں اور browser میں اجازت دیں۔
4. مزید accounts اسی طرح شامل کریں۔
5. بائیں طرف account یا **All Drives** منتخب کر کے files استعمال کریں۔

## Builder

Requirements: Windows 11 x64, Node.js 22 LTS, npm, and Git.

```powershell
npm install
npm run desktop:install
npm run desktop:build
```

Artifacts `apps/desktop/dist` میں installer اور portable EXE کے طور پر بنیں گے۔
Release سے پہلے صاف Windows 11 VM، non-admin account، install/uninstall، OAuth
callback، multiple accounts، بڑی upload، preview، download اور token refresh آزمائیں۔

Microsoft Store کے لیے reserved identity، MSIX packaging، privacy URL، support
URL، screenshots اور Partner Center certification الگ حتمی release مرحلہ ہیں۔
