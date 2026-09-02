# FarooqDrive Windows Build — Credential-Free

یہ FarooqDrive کا public/free build ہے۔

## اہم تبدیلی
Windows installer کے اندر کسی developer یا publisher کی Google Client ID/Secret شامل نہیں ہوتی۔
ہر user پہلی launch پر اپنا Google OAuth Desktop Client بناتا ہے اور FarooqDrive کے Setup Wizard میں اپنی credentials داخل کرتا ہے۔

اس لیے GitHub Actions میں اب یہ secrets درکار نہیں:
- GOOGLE_OAUTH_CLIENT_ID
- GOOGLE_OAUTH_CLIENT_SECRET

## Build کا نتیجہ
GitHub Actions Windows runner خود بنائے گا:
- `FarooqDrive-Setup-0.9.3-x64.exe`
- `FarooqDrive-Portable-0.9.3-x64.exe`

## Code signing صرف optional publisher step ہے
اگر بعد میں direct-download installer sign کرنا ہو تو:
- `CSC_LINK`
- `CSC_KEY_PASSWORD`

رکھے جا سکتے ہیں۔

## عام user کا طریقہ
Install → FarooqDrive کھولیں → Google Cloud instructions دیکھیں → اپنی Client ID/Secret بنائیں → app میں paste کریں → Google Drive connect کریں۔

Public GitHub repository یا Windows installer میں کسی شخص کی private Google credentials شامل نہیں ہوں گی۔
