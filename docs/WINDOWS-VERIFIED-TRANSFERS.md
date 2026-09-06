# Windows verified transfers — private candidate

Scope: `onedrive-foundation`, Windows private testing only. This does not change
the published web/Store release or the Android branch.

## Using the explorer

Click an account to open its contents. Expand its arrow to load its immediate
files/folders; expand subfolders as needed. The tree does not run an account-wide
scan. Refresh reloads expanded folders. Back/Up/breadcrumbs and file actions share
one row. Name sorting and View stay together on the right. View supports Extra
large icons, Large icons, Medium icons, Small icons, List, Details, Tiles and
Content. Account name/email fonts are both 13 px. Existing text identification
is retained; no provider logos have been added.
Checkboxes select multiple items. Copy/Cut, open a destination, then Paste.
Dragging within FarooqDrive onto an account, folder, breadcrumb or the current
folder's blank area asks Copy/Move/Cancel. The red information icon beside
Activity opens the transfer disclosure, latest result and any current error.
Native drag from/to Windows Explorer and preview/thumbnails are not included.

## Transfer safety

The app first enumerates the selected source tree. It rejects overlapping
selections, cycles and destinations inside that tree. It copies files through
an app-owned temporary disk file, uploads sequential 10 MiB chunks, then downloads
the destination again and compares SHA-256. Names alone and sizes alone never
authorize source cleanup. Existing destination files are not overwritten: Google
creates another file and OneDrive uses rename-on-conflict.

Cut only fills the clipboard. For Move, all copies must verify before the final
Yes/No dialog. No, dismissing the dialog or no confirmation handler retains the
originals. Yes permits only eligible OneDrive source files to enter the Recycle
Bin. Source and destination versions are checked again, and source DELETE uses
If-Match. A changed file or failed request stops further cleanup. No permanent
delete endpoint is used.

Google v3 conditional Trash semantics have not been established, so Google source
files are retained even after Move. Original folder containers remain: the app
never deletes an entire source folder and thereby risks deleting new children.
Files inside a copied OneDrive folder can be confirmed for individual cleanup.
The result and seven-day local Activity report completed cleanup; batch cleanup
is not atomic. Files copied before an interruption may remain at the destination.

## Limits and temporary storage disclosure

- No fixed account-count cap exists in the app. The owner has confirmed five
  simultaneous accounts (three Google, two OneDrive). More accounts are not a
  tested reliability guarantee; provider throttling, permissions, quotas and
  device resources remain constraints.
- Candidate transfer cap: 1 GiB per file, 10,000 items, 64 nested folder levels.
  This is an application guard, not a claimed provider maximum or a completed
  1 GiB real-account performance test.
- Transfer storage: `<Windows temp>/FarooqDrive-transfers/job-*/payload`.
  Only one file is spooled at a time. Reserve the largest file's size plus normal
  OS free space. Disk write failures stop the operation. This candidate does not
  reserve disk space or preflight free space with a native Windows disk API.
- The app does not encrypt temporary file contents. OS/device encryption and
  filesystem access controls apply. Normal completion/failure removes only the
  current operation's temporary folder. A crash may leave a folder; close the
  app before manually removing its leftover job folders.
- Transfers use the user's internet connection. Verification downloads a second
  copy from the destination, increasing bandwidth and time.
- Automatic restart/resume is not implemented. On interruption, sources without
  completed confirmed cleanup remain; retry may create additional destination
  copies. Incomplete provider upload sessions expire under provider rules.
- OneDrive files up to 4 MiB, including empty files, use the direct content upload
  endpoint with explicit rename-on-conflict. Larger files use upload sessions.
  Unsupported
  Google-native formats, shortcuts and remote packages are not transferred.
  Within the same Google account, native Copy preserves its native format using
  Google's copy operation. These native copies are explicitly reported separately
  as not byte-verified and are never eligible for source cleanup. Between accounts,
  Google Docs/Sheets/Slides export to Office files, drawings to PNG. Export
  output bytes are verified; native sharing, comments and version history are
  not preserved by the exported file.
- The Windows Upload picker now streams into the disk cache and verifies the
  destination SHA-256, for both providers, with the 1 GiB guard. Local source
  files are never removed. Download-to-PC still buffers bytes and OneDrive
  Download-to-PC remains capped at 32 MiB. Android/iOS large-file limits are not
  established.

## Private acceptance checks

Use disposable test files first. Copy a binary file both ways between Google and
OneDrive, and between two OneDrive accounts; open the destination. Try nested
folders, duplicate names, Details/List/icons, and drag onto an expanded folder.
For OneDrive Cut/Paste, choose No and confirm both remain. Repeat with Yes and
confirm the original is in the OneDrive Recycle Bin. Modify an original while
the final dialog is open; cleanup must stop. Test network interruption and low
disk space. Check source files remain and review any partial copies before retry.

## Provider references

- [Microsoft upload sessions](https://learn.microsoft.com/en-us/graph/api/driveitem-createuploadsession?view=graph-rest-1.0)
- [Microsoft direct uploads](https://learn.microsoft.com/en-us/graph/api/driveitem-put-content?view=graph-rest-1.0)
- [Conflict behavior in the request URL](https://learn.microsoft.com/en-us/graph/api/resources/driveitem?view=graph-rest-1.0#instance-attributes)
- [Microsoft conditional Recycle Bin deletion](https://learn.microsoft.com/en-us/graph/api/driveitem-delete?view=graph-rest-1.0)
- [Google resumable uploads](https://developers.google.com/workspace/drive/api/guides/manage-uploads)

## اردو

یہ صرف Windows آزمائشی نسخہ ہے۔ بائیں طرف ہر account اور فولڈر کے تیر سے اس
کا مواد کھولیں۔ اندرونی drag-and-drop میں Copy یا Move منتخب کریں۔ Move پہلے
نقل اور SHA-256 جانچ کرتا ہے، پھر اصل فائل ہٹانے کی آخری اجازت مانگتا ہے۔ No
پر دونوں نقول رہتی ہیں۔ اس نسخے میں صرف OneDrive کی غیر تبدیل شدہ فائلیں محفوظ
شرط کے ساتھ Recycle Bin میں جاتی ہیں۔ Google کی اصل فائلیں اور اصل فولڈر
containers برقرار رہتے ہیں۔

فی فائل 1 GiB، فی کام 10,000 اشیاء اور 64 سطحوں کی آزمائشی حد ہے۔ عارضی فائل
ہارڈ ڈسک استعمال کرتی ہے اور app اسے encrypt نہیں کرتی۔ سب سے بڑی فائل اور
Windows کے لیے کافی خالی جگہ رکھیں۔ کام کے بعد متعلقہ عارضی فولڈر مٹتا ہے؛
crash پر بچی ہوئی job folders ایپ بند کرکے ہٹائیں۔ تصدیق میں منزل سے مکمل
فائل دوبارہ download ہوتی ہے۔ خودکار resume، Windows Explorer کے ساتھ بیرونی
drag-and-drop اور موبائل حدود ابھی شامل نہیں۔
