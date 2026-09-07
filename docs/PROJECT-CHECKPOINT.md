# Update — 7 September 2026: browser OneDrive download link repair

Owner reported Copy/Paste from OneDrive to Google failed with `OneDrive browser download URL unavailable.` This locates the failure before Google upload, in source-link resolution; Copy itself only stages the selection.

- Tested candidate: `7546012039066c6b782064a02bf5daa64f045dbe`; passing analyzer/tests/web build run `34085967085`.
- Browser download now fetches full item metadata instead of relying only on a narrow `$select` annotation projection. If absent, retries the documented `select=id,@microsoft.graph.downloadUrl` form. Missing links still fail safely.
- Validates file identity and HTTPS URL; never sends the Graph token to content storage. Native Windows download route unchanged.
- Regression tests cover missing annotation fallback, wrong item/unsafe URL rejection, token isolation, OneDrive-to-Google upload and SHA-256 verification, and corruption rejection. These use simulated provider responses; owner cloud transfer retest is required.
- Main deployment pin updated in commit `7816fccf18114a8d107cf50837a90d49ed716cdc`. Confirm latest Pages run and release.json before asking owner to retest. Version stays 21.1, browser 32 MiB limit, final Move Yes/No retained.
- Do not claim this proves the owner's full transfer works until they confirm it. No new permission/secret or Store release was introduced.

---

# FarooqDrive project memory — resume 7 September 2026

Read this checkpoint before changing code. User: Mohammad Farooq; assistant: Zain. Communicate in Pakistani Urdu script. Continue authorized work without repeated permission prompts. Keep official icon and version 21.1; no secrets in GitHub. This file is durable project context, not a claim of writing ChatGPT account memory.

## Source and verified release

- Main documentation/deployment tip at checkpoint: `deef5ddd8f3e234cb1a710e18c9bb14a218e3f47`.
- Windows branch `onedrive-foundation`: tip `5e97f7fb79543f9da88f400d993b2fea763da068`; tested runtime `8a63c7cf966f11c315ba549fc68a202e3ec1ec04`; passing run [34057024264](https://github.com/farooqmusicai/FarooqDrive/actions/runs/34057024264). Installer artifact 9996329274; portable 9996328663.
- Web branch `web-update-21-1`: previous tip `9b73467d2e891c53534af2db4e2038c45be031c5`; live tested runtime `e1996e90a66c51a87ca6ff9e38d02893a52c9283`.
- Web tests/build passed [34058314279](https://github.com/farooqmusicai/FarooqDrive/actions/runs/34058314279). Latest successful Pages publication after OneDrive guides: [34059055409](https://github.com/farooqmusicai/FarooqDrive/actions/runs/34059055409).
- Main workflow pins web source above. Main apps/flutter is not the current Web/Windows implementation. Do not blind-merge branches to remove Compare & pull request banners.
- [Live app](https://farooqmusicai.github.io/FarooqDrive/); release.json identifies source and 32 MiB browser limit. Owner confirmed OneDrive login, folder list and storage display working. Full cloud transfer acceptance remains separate.
- pubspec 21.1.0+22; MSIX config 21.1.0.0. No new Store submission was made in this work; current live Store certification/version was not verified.

## Microsoft configuration confirmed by owner screenshots

App FarooqDrive. Public client ID `28058750-66c8-4a36-8d4d-227142d80a00`. Audience: any Entra tenant + personal Microsoft accounts. Delegated Graph permissions User.Read and Files.ReadWrite. Do not widen to Files.ReadWrite.All without an actual need.

- Desktop platform: http://localhost.
- SPA platform: https://farooqmusicai.github.io/FarooqDrive/microsoft-callback.html.
- Both were shown saved; owner then confirmed web login. Do not ask to re-register them.
- Branding home/terms/privacy/support URLs point to https://www.mymandoob.com/farooqdrive/ and its terms.html, privacy.html, support.html pages.
- Publisher verification remained Unverified in the latest branding screenshot. Entra publisher verification is separate from Store publisher identity.
- MSAL web uses memory-only cache, reconnect after reload, locally bundled 5.19.0 with license. Standalone callback uses redirect bridge, not Flutter.
- GitHub FAROOQDRIVE_MICROSOFT_CLIENT_ID supplies public app ID to MICROSOFT_WEB_CLIENT_ID / MICROSOFT_DESKTOP_CLIENT_ID. Browser never receives a client secret.
- Last toggles screenshot: public client flows disabled, Live SDK enabled; no later toggle changes verified. Do not change them speculatively.

## Delivered behavior and hard limits

Compact Explorer toolbar, 8 views, saved Light/Dark, account tooltips, shared remembered heading sorting, expandable cloud folders, internal dragging, background metadata scan with progress and persistent results. Name+known-size duplicates are candidates, not content equality. No scan deletes anything.

Verified Move: whole batch copy → SHA-256 destination verification → final Yes/No. Only unchanged OneDrive source files support conditional cleanup; Google originals and source folder containers remain. No/dismiss keeps both. Interruption may leave destination copies. No restart resume.

Windows transfer/upload 1 GiB/file using unencrypted app temp disk; Web 32 MiB using bounded browser memory. Batch 10,000 items/64 levels. OneDrive download-to-device 32 MiB. No fixed app account cap; resources/quotas/tenant policies apply. No mounted-drive or full OS clipboard claim.

Latest scan repair: delta/paging correctness, timeouts, progress/errors, no Refresh cancellation, first-click tab behavior, batched yielding, keep previous index on failure. Web reconnect restores saved metadata index. Owner's successful full scan completion remains unconfirmed; screenshots only showed scanning in progress.

## Tomorrow, in order

1. Confirm Repo Settings → Pages → Source is GitHub Actions. Legacy Jekyll also ran on recent main pushes. Main workflow now runs on all main pushes and republishes the tested app, but owner setting confirmation is still missing.
2. Test final Windows scan results once, including background navigation and saved results. Capture account/stage/error if failure.
3. Test disposable Web upload/copy and Move→No; only then disposable OneDrive cleanup→Yes. Preserve originals on failure.
4. Audit hosted website text: an updated ZIP was delivered earlier, but upload/content was not independently verified and some web text may predate browser OneDrive. Align browser privacy/session/memory and 32 MiB limit.
5. Check current Google Verification Center/Entra publisher actions with owner. Older Google handoff said scope unapproved/in review; current approval not verified. No new Google scope added.
6. Only after acceptance proceed with Store candidate or mobile milestone. Never equate installer success with Store MSIX startup success.

## Android / Apple

Read-only checked android-foundation `1d0f708aa62f7d2f3aaf35bd8ca34810a0a8ea54`. CI creates runner using application ID com.farooqdrive.app and builds private debug APK. google_auth_mobile.dart still explicitly blocks sign-in as an unconfigured placeholder. Another conversation mentioned permanent signing key work; reconcile protected signing/OAuth state before recreating anything. Apple bundle/Team/provisioning not verified. Android, iPhone/iPad, macOS remain Coming soon.

## Documentation and continuation file

Main includes README and docs/ONEDRIVE-GUIDE.md, ONEDRIVE-GUIDE-URDU.md, WEB-21.1-UPDATE.md, USER-HELP.md, USER-HELP-URDU.md, WINDOWS-21.1-RELEASE-TEXT.md. Historical sections can contain stale status; use latest checkpoint and live refs.

Owner received standalone **FarooqDrive-Handoff-2026-09-07-v21.1.md** with detailed Urdu handoff, Microsoft setup, builds, safety rules, source map and next-chat prompt. Read it when attached. Scratch paths may expire. The v20 attachment is historical; do not revert to its version or Google-only description.
