# FarooqDrive 21.1 — OneDrive رہنمائی

FarooqDrive میں Google Drive اور Microsoft OneDrive اکاؤنٹس ایک ہی فائل مینیجر میں استعمال کیے جا سکتے ہیں۔ اصل cloud storage متعلقہ کمپنی کے پاس رہتی ہے۔

## اکاؤنٹ شامل کرنا

1. **Add account → Microsoft OneDrive** منتخب کریں۔
2. Microsoft کے صفحے پر login کرکے اجازت منظور کریں۔
3. بائیں پینل میں اکاؤنٹ منتخب کریں؛ تیر سے فولڈرز پھیلائیں یا فہرست میں فولڈر پر double-click کریں۔
4. Back، Up اور اوپر کے راستے سے واپس جائیں۔ All Drives تمام منسلک اکاؤنٹس کو یکجا دکھاتا ہے۔
5. اکاؤنٹ پر mouse رکھنے سے پورا نام اور email نظر آتے ہیں۔

مزید اکاؤنٹس کے لیے یہی عمل دہرائیں۔ ایپ کی کوئی مقررہ account-count حد نہیں؛ آلے کی گنجائش، provider کی حدود اور ادارے کی اجازت لاگو ہوتی ہے۔ ذاتی اور work/school Microsoft accounts کے لیے sign-in ترتیب موجود ہے؛ ادارہ administrator کی منظوری مانگ سکتا ہے۔

## ظاہری شکل اور ترتیب

دن اور رات کے لیے Light/Dark انتخاب محفوظ رہتا ہے۔ آٹھ views موجود ہیں: Extra large، Large، Medium، Small icons، List، Details، Tiles اور Content۔ Name، Account، Size یا Modified پر کلک سے ترتیب بدلتی ہے؛ دوبارہ کلک سے الٹ جاتی ہے۔ یہ ترتیب تمام ٹیبز میں یاد رہتی ہے اور فولڈرز پہلے دکھتے ہیں۔

## Copy، Cut اور Move

Copy/Cut کے بعد منزل والا اکاؤنٹ یا فولڈر کھول کر Paste کریں۔ ایپ کے اندر drag-and-drop بھی یہی transfer طریقہ استعمال کرتا ہے۔

فائل پہلے منزل پر upload ہوتی ہے؛ پھر دوبارہ download کرکے SHA-256 سے مواد کی جانچ ہوتی ہے۔ اس لیے اضافی انٹرنیٹ استعمال ہوتا ہے۔

- Move شروع ہوتے ہی اصل فائل حذف نہیں ہوتی۔
- مکمل batch کی جانچ کے بعد آخری **Yes/No** پوچھا جاتا ہے۔
- **No** یا dialog بند کرنے پر دونوں نقول رہتی ہیں۔
- **Yes** پر صرف غیر تبدیل شدہ OneDrive اصل فائلیں شرط کے ساتھ Recycle Bin میں منتقل ہونے کی اہل ہیں۔
- Google کی اصل فائلیں اور اصل folder containers برقرار رہتے ہیں۔
- ناکام یا نامکمل transfer اصل فائل حذف کرنے کی اجازت نہیں دیتا۔ منزل پر جزوی یا مکمل نقل رہ سکتی ہے؛ دوبارہ کوشش سے پہلے Activity دیکھیں۔

یہ ایپ cloud accounts کو Windows drive letters کی شکل میں mount نہیں کرتی؛ پورے Windows clipboard کی تمام سہولتیں شامل نہیں۔

## حدود اور عارضی جگہ

| سہولت | Windows | Web |
| --- | --- | --- |
| فی فائل transfer/upload | 1 GiB | 32 MiB |
| فی batch | 10,000 اشیاء، 64 فولڈر سطحیں | یہی حد |
| OneDrive download | 32 MiB | 32 MiB |
| عارضی نقل | ہارڈ ڈسک | Browser memory |

Windows کی عارضی نقل FarooqDrive خود encrypt نہیں کرتا۔ مکمل یا ناکام کام اپنی عارضی فائل صاف کرتا ہے؛ crash کے بعد بچی ہوئی job folders ایپ بند کرکے صاف کریں۔ مقام Help میں موجود ہے۔

ویب میں transfer کے دوران tab کھلا رکھیں؛ کئی memory buffers استعمال ہو سکتے ہیں۔ دونوں میں restart کے بعد خودکار resume موجود نہیں۔

## Scan اور نتائج

Scan all فائلوں کی metadata فہرست بناتا ہے۔ Duplicate scan پس منظر میں چلتا ہے اور آپ browsing جاری رکھ سکتے ہیں۔ نتائج محفوظ رہتے ہیں؛ Rescan all سے تازہ ہوتے ہیں۔ فائل کی تبدیلی پر پرانی فہرست outdated دکھائی جاتی ہے۔

یکساں نام اور معلوم سائز صرف ممکنہ duplicates ہیں؛ یہ یکساں مواد کی ضمانت نہیں۔ Same-name نتائج مختلف یا نامعلوم سائز والی فائلیں دکھاتے ہیں۔ Scan خود کوئی فائل حذف نہیں کرتا۔ خرابی پر پچھلی فہرست برقرار رہتی ہے اور متعلقہ اکاؤنٹ یا مرحلے کی معلومات دکھتی ہیں۔

## ویب login، رازداری اور دستیابی

Web میں Microsoft session عارضی memory میں ہے؛ مکمل reload کے بعد اکاؤنٹ دوبارہ ملائیں۔ محفوظ index میں فائلوں کی metadata ہوتی ہے، اصل مواد یا OAuth tokens نہیں۔ Settings اور Activity browser میں رہ سکتی ہیں؛ مشترکہ کمپیوٹر پر disconnect کرکے site data صاف کریں۔

صارف نے 6 ستمبر 2026 کو ویب پر OneDrive login، فولڈر فہرست اور storage display کے درست چلنے کی تصدیق کی۔ Transfer کے لیے الگ چھوٹی آزمائشی فائل استعمال کریں اور Move میں پہلے No آزمائیں۔

نسخہ **21.1** برقرار ہے۔ **Android، iPhone/iPad اور macOS apps جلد آ رہی ہیں۔**

[مکمل انگریزی رہنمائی](ONEDRIVE-GUIDE.md) · [مدد](https://www.mymandoob.com/farooqdrive/support.html) · [رازداری](https://www.mymandoob.com/farooqdrive/privacy.html) · [شرائط](https://www.mymandoob.com/farooqdrive/terms.html)
