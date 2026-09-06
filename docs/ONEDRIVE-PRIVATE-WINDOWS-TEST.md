# FarooqDrive: private Windows OneDrive test

This is a development build from onedrive-foundation. Do not submit it to Microsoft Store or describe OneDrive transfer support as complete.

## Owner checks
1. Open Add account, then Microsoft OneDrive — read-only test.
2. Sign in using the system browser. The official Windows build uses the configured Microsoft client ID; it should not require you to paste it.
3. Approve requested delegated access. If organization consent or publisher verification blocks access, record the message without sharing tokens or passwords.
4. Return to FarooqDrive and check account name, root folders and quota.
5. Open a nested folder and use Back/Up. Download a disposable test file smaller than 32 MiB and compare it locally.
6. Close/reopen the app. Confirm the Microsoft account restores and can browse again.
7. Add a second account; confirm both Microsoft and Google accounts remain distinct.
8. Disconnect the test Microsoft account and reopen. Its saved session should be gone; cloud files remain.

Read-only means OneDrive upload, copy, move, rename and Trash are deliberately blocked in this build. Move/Cut-Paste source removal is temporarily blocked for ALL providers until the final verification and Yes/No safeguards are implemented. Google Copy remains available. Explicit Google Trash remains a separate existing action.

## Data and limits
- Files and metadata are requested directly from Microsoft Graph on the user's device.
- Microsoft refresh tokens and profile records use flutter_secure_storage. Access tokens are held in memory. No Microsoft client secret is used.
- Existing local activity history may include account email, file names and action descriptions. Tokens and download URLs must not be logged.
- Download uses small streamed reads but accumulates at most 32 MiB for the existing save UI. Unknown-size or larger files are rejected. Disk-backed large transfers and resumable local cache are NOT implemented yet.
- Shared remote items and special package files may need the provider website.
- Search indexing remains user-triggered. Full scan cancellation and per-account partial indexing are follow-up work.
- Public Help/Privacy/Terms and Store claims must be reviewed after final transfer behavior is implemented.

## پاکستانی اردو
یہ صرف Windows کا نجی OneDrive test ہے۔ Add account سے Microsoft OneDrive منتخب کرکے browser میں login کریں، folders اور quota دیکھیں، پھر 32 MiB سے چھوٹی آزمائشی فائل download کریں۔ App بند کرکے دوبارہ کھولیں اور account کی بحالی چیک کریں۔

اس build میں OneDrive پر upload، move، copy یا delete دستیاب نہیں۔ بڑی فائلوں کا عارضی disk folder اور اصل فائل ہٹانے سے پہلے آخری Yes/No والا مرحلہ ابھی تیار نہیں۔ اس حفاظتی مرحلے کے تیار ہونے تک تمام providers کے Move اور Cut/Paste عارضی طور پر بند ہیں؛ Google Copy دستیاب ہے۔ Microsoft Store پر یہ build جمع نہ کروائیں۔
