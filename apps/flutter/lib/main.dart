import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'drive_controller.dart';
import 'diagnostics.dart';
import 'google_auth.dart';
import 'models.dart';
import 'native_file_icon.dart';
import 'official_icon_data.dart';
import 'explorer_widgets.dart';
import 'transfer_spool.dart';

const _driveColors = <Color>[
  Color(0xff00a884),
  Color(0xffff8a00),
  Color(0xffb45cff),
  Color(0xffe83e6f),
  Color(0xff17a2d4),
  Color(0xffd4a017),
];

Color _accountColor(DriveController controller, String accountId) {
  final index = controller.accounts.indexWhere((item) => item.id == accountId);
  return _driveColors[(index < 0 ? 0 : index) % _driveColors.length];
}

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var amount = bytes.toDouble();
  var unit = 0;
  while (amount >= 1024 && unit < units.length - 1) {
    amount /= 1024;
    unit++;
  }
  final decimals = unit == 0 ? 0 : (unit >= 3 ? 2 : 1);
  return '${amount.toStringAsFixed(decimals)} ${units[unit]}';
}

String _formatCombinedCapacity(Iterable<DriveAccount> accounts) {
  final limits = accounts
      .map((account) => account.storageLimit)
      .whereType<int>()
      .toList()
    ..sort((a, b) => b.compareTo(a));
  if (limits.isEmpty) return 'Not reported';
  final total = limits.fold<int>(0, (sum, value) => sum + value);
  if (limits.length == 1) return _formatBytes(total);
  final largest = limits.first;
  final remainder = total - largest;
  const oneTerabyte = 1024 * 1024 * 1024 * 1024;
  if (largest >= oneTerabyte && remainder > 0 && remainder < oneTerabyte) {
    return '${_formatBytes(largest)} + ${_formatBytes(remainder)}';
  }
  return _formatBytes(total);
}

bool shouldShowDriveSidebar(double width, {required bool pinned}) =>
    width >= 1360 || pinned;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    writeDiagnostic('Flutter error: ${details.exception}', details.stack);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    writeDiagnostic('Unhandled platform error: $error', stack);
    return true;
  };
  runZonedGuarded(
    () => runApp(const FarooqDriveApp()),
    (error, stack) => writeDiagnostic('Unhandled async error: $error', stack),
  );
}

class FarooqDriveApp extends StatelessWidget {
  const FarooqDriveApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FarooqDrive',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff0b67d1),
            surface: const Color(0xfff6f8fc),
          ),
          scaffoldBackgroundColor: const Color(0xfff6f8fc),
          fontFamily: 'Arial',
          visualDensity: VisualDensity.compact,
          useMaterial3: true,
        ),
        home: const FileManagerPage(),
      );
}

class FileManagerPage extends StatefulWidget {
  const FileManagerPage({super.key});

  @override
  State<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> {
  final controller = DriveController();
  bool _sidebarPinned = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(_changed);
    controller.confirmSourceCleanup = (files, retained) async {
      if (!mounted) return false;
      return await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Verified copies are ready. Remove originals?'),
        content: SizedBox(width: 560, child: SingleChildScrollView(child: Text(
          'All copied file contents passed SHA-256 verification.\n\n'
          'Move these ${files.length} original file(s) to their source Recycle Bin?\n'
          'No keeps both copies. Source and destination versions are checked again before cleanup.\n\n'
          '${files.map((copy) => "${copy.source.item.name}\n${copy.sourceAccount.email} → ${copy.destination.email} / ${copy.copy.item.name}").join("\n\n")}\n\n'
          '$retained other source file(s) must remain because conditional cleanup is unavailable. Original folder containers remain.'))),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: const Text('No — keep originals')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes — move originals to Recycle Bin')),
        ],
      )) ?? false;
    };
    _loadSidebarPreference();
    controller.initialize();
  }

  Future<void> _loadSidebarPreference() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _sidebarPinned =
            preferences.getBool('farooqdrive.sidebarPinned') ?? false;
      });
    } catch (_) {
      // The menu still works for the current session if preferences are unavailable.
    }
  }

  Future<void> _setSidebarPinned(bool value) async {
    if (mounted) setState(() => _sidebarPinned = value);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('farooqdrive.sidebarPinned', value);
    } catch (_) {
      // Keep the current-session pin state even if persistence is unavailable.
    }
  }

  @override
  void dispose() {
    controller
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
    final message = controller.error;
    if (message != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      });
    }
  }

  Future<String?> _ask(
    String title, {
    String initial = '',
    bool obscure = false,
  }) async {
    final input = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: input,
          autofocus: true,
          obscureText: obscure,
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _settings() async {
    final value = await _ask(
      GoogleAccountAuthorizer.clientIdLabel,
      initial: controller.webClientId,
    );
    if (value != null && value.isNotEmpty) {
      await controller.saveClientId(value);
    }
    if (GoogleAccountAuthorizer.requiresClientSecret) {
      final secret = await _ask(
        'Google Desktop Client Secret',
        initial: controller.desktopClientSecret,
        obscure: true,
      );
      if (secret != null && secret.isNotEmpty) {
        await controller.saveClientSecret(secret);
      }
    }
    if (controller.supportsMicrosoft && !controller.hasOfficialMicrosoftClientId && mounted) {
      final id = await _ask('Microsoft Application (client) ID', initial: controller.microsoftClientId);
      if (id != null && id.isNotEmpty) await controller.saveMicrosoftClientId(id);
    }
  }

  Future<void> _addAccount() async {
    if (controller.supportsMicrosoft) {
      final provider = await showDialog<CloudProviderType>(context: context, builder: (context) => SimpleDialog(
        title: const Text('Add account'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, CloudProviderType.google), child: const Text('Google Drive')),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, CloudProviderType.onedrive), child: const Text('Microsoft OneDrive')),
        ],
      ));
      if (provider == null || !mounted) return;
      if (provider == CloudProviderType.onedrive) {
        if (!controller.hasMicrosoftClientId) {
          final id = await _ask('Microsoft Application (client) ID', initial: controller.microsoftClientId);
          if (id == null) return;
          await controller.saveMicrosoftClientId(id);
          if (!controller.hasMicrosoftClientId) return;
        }
        await controller.addMicrosoftAccount();
        return;
      }
    }
    if (!controller.hasRequiredCredentials ||
        (!controller.hasClientId &&
            GoogleAccountAuthorizer.buildClientId.isEmpty)) {
      await _settings();
      if (!controller.hasRequiredCredentials) return;
    }
    await controller.addAccount();
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file?.bytes == null) return;
    await controller.upload(file!.name, file.bytes!, null);
  }

  Future<void> _download() async {
    for (final item in controller.selectedItems) {
      if (item.isFolder) continue;
      if (item.mimeType.startsWith('application/vnd.google-apps.')) {
        final link = item.webViewLink;
        if (link != null) await launchUrl(Uri.parse(link));
        continue;
      }
      final bytes = await controller.download(item);
      final dot = item.name.lastIndexOf('.');
      await FileSaver.instance.saveFile(
        name: dot > 0 ? item.name.substring(0, dot) : item.name,
        bytes: bytes,
        ext: dot > 0 ? item.name.substring(dot + 1) : '',
        mimeType: MimeType.other,
        customMimeType: item.mimeType,
      );
    }
  }

  Future<void> _showActivityLog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history),
            SizedBox(width: 10),
            Text('Activity — last 7 days'),
          ],
        ),
        content: SizedBox(
          width: 680,
          height: 500,
          child: controller.activityLog.isEmpty
              ? const Center(child: Text('No activity recorded yet.'))
              : ListView.separated(
                  itemCount: controller.activityLog.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = controller.activityLog[index];
                    return ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(entry.action),
                      subtitle: Text([
                        entry.details,
                        if (entry.accountEmail != null) entry.accountEmail!,
                      ].join('\n')),
                      trailing: Text(
                        DateFormat.MMMd().add_jm().format(entry.timestamp),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton.icon(
            onPressed: controller.activityLog.isEmpty
                ? null
                : () async {
                    await controller.clearActivityLog();
                    if (context.mounted) Navigator.pop(context);
                  },
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clear history'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline),
            SizedBox(width: 10),
            Text('Help — How FarooqDrive works'),
          ],
        ),
        content: DefaultTabController(
          length: 2,
          child: SizedBox(
            width: 720,
            height: 480,
            child: Column(
              children: [
                TabBar(tabs: [Tab(text: 'English'), Tab(text: 'اردو')]),
                SizedBox(height: 14),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HelpSection(title: '1. Connect your Drives', text: 'Select Add account and choose Google Drive or, on Windows, Microsoft OneDrive. Approve access in your browser. Repeat for each account.'),
                            _HelpSection(title: 'Windows transfers and limits', text: 'Copy/Paste and internal drag-and-drop use a temporary disk file, sequential uploads and full SHA-256 destination verification. Private candidate limit: 1 GiB per file, 10,000 items and 64 folder levels per batch. Keep enough free disk space for the largest file plus normal Windows needs. Transfer traffic uses your internet connection, including a second destination download for verification. Google-native documents are exported to Office formats or PNG; unsupported formats are retained. Move asks Yes/No after verification. Only unchanged OneDrive source files support conditional Recycle Bin cleanup; Google source files and original folder containers remain. No keeps both copies. Interrupted uploads may leave destination copies; retries create new copies. Automatic resume after restarting is not available. Native download and file-picker upload still use memory; OneDrive download limit is 32 MiB. Account connections have no fixed app cap; service quotas, organization policies and device resources apply.'),
                            _HelpSection(title: 'Temporary storage', text: 'Transfer cache: ${TransferSpool.cachePath}. Files are not encrypted by FarooqDrive in this folder. Completed or failed jobs remove their own cache files; an app crash may leave job folders here. Close FarooqDrive before manually removing leftover job folders. Transfers never delete original local files.'),
                            _HelpSection(title: '2. Browse everything together', text: 'All Drives combines connected accounts. Select one account for its My Drive. Double-click a folder to open it; use Back, Up or the path bar to return.'),
                            _HelpSection(title: '3. All, Folders and Files', text: 'All shows folders and files together. The other tabs filter the list. Search works across all indexed Drives and every count changes to match the results currently shown.'),
                            _HelpSection(title: '4. Manage files', text: 'Select one or more items, then use Download, Copy, Cut, Paste, Rename or Trash. For Cut or Copy, open the destination Drive or folder before selecting Paste.'),
                            _HelpSection(title: '5. Storage and activity', text: 'Storage cards show provider-reported capacity and usage. The history icon shows activity recorded on this device for the last 7 days.'),
                            _HelpSection(title: 'Privacy and safety', text: 'Files transfer directly between this device and the selected cloud providers. FarooqDrive does not operate an intermediate file-storage server.'),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        child: Directionality(
                          textDirection: ui.TextDirection.rtl,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _HelpSection(title: '۱۔ اپنی گوگل ڈرائیوز منسلک کریں', text: 'گوگل اکاؤنٹ شامل کریں منتخب کریں اور براؤزر میں گوگل ڈرائیو کی اجازت منظور کریں۔ ہر مطلوبہ اکاؤنٹ کے لیے یہی عمل دہرائیں۔'),
                              _HelpSection(title: 'ونڈوز Copy اور Move', text: 'OneDrive بھی Add account سے شامل کریں۔ بائیں تیر سے فولڈر کھولیں اور فائل کو مطلوبہ فولڈر پر drag کریں۔ Move پہلے نقل بناتا ہے، پھر مکمل SHA-256 جانچ کے بعد آخری Yes/No پوچھتا ہے۔ No پر دونوں نقول رہتی ہیں۔ صرف غیر تبدیل شدہ OneDrive فائلیں محفوظ شرط کے ساتھ Recycle Bin میں جا سکتی ہیں؛ Google کی اصل فائلیں اور اصل فولڈرز برقرار رہتے ہیں۔'),
                              _HelpSection(title: 'عارضی جگہ اور حدود', text: 'اس آزمائشی نسخے میں فی فائل 1 GiB، فی کام 10,000 اشیاء اور 64 فولڈر سطحوں کی حد ہے۔ سب سے بڑی فائل کے لیے ہارڈ ڈسک میں خالی جگہ رکھیں۔ FarooqDrive کی عارضی نقل encrypted نہیں ہے۔ کام کے بعد عارضی نقل مٹتی ہے؛ crash پر بچی ہوئی job folders ایپ بند کرکے ہٹائیں۔ دوبارہ شروع ہونے پر خودکار resume موجود نہیں۔ منزل کی تصدیق کے لیے فائل دوبارہ download ہوتی ہے، اس لیے انٹرنیٹ بھی استعمال ہوتا ہے۔ Accounts کی کوئی مقررہ app حد نہیں۔'),
                              _HelpSection(title: '۲۔ تمام مواد ایک ساتھ دیکھیں', text: 'تمام ڈرائیوز منسلک اکاؤنٹس کا مواد یکجا دکھاتا ہے۔ کسی ایک اکاؤنٹ کی مائی ڈرائیو دیکھنے کے لیے اسے منتخب کریں۔ فولڈر کھولنے کے لیے اس پر دو مرتبہ کلک کریں۔'),
                              _HelpSection(title: '۳۔ تمام، فولڈرز اور فائلیں', text: 'تمام والے حصے میں فولڈرز اور فائلیں اکٹھی نظر آتی ہیں۔ دوسرے حصے فہرست کو الگ کرتے ہیں۔ تلاش تمام فہرست شدہ ڈرائیوز میں کام کرتی ہے اور تعداد صرف موجودہ نتائج کے مطابق بدلتی ہے۔'),
                              _HelpSection(title: '۴۔ فائلوں کا انتظام', text: 'ایک یا زیادہ اشیاء منتخب کرکے ڈاؤن لوڈ، نقل، کاٹیں، چسپاں کریں، نام تبدیل کریں یا کوڑے دان میں منتقل کریں۔ کاٹنے یا نقل کرنے کے بعد منزل والا فولڈر کھول کر چسپاں کریں۔'),
                              _HelpSection(title: '۵۔ گنجائش اور سرگرمی', text: 'گنجائش کے خانے گوگل کی فراہم کردہ معلومات دکھاتے ہیں۔ تاریخ کا نشان اس آلے پر گزشتہ سات دنوں کی سرگرمی دکھاتا ہے۔'),
                              _HelpSection(title: 'رازداری اور حفاظت', text: 'فائلیں براہ راست آپ کے آلے یا براؤزر اور گوگل ڈرائیو کے درمیان منتقل ہوتی ہیں۔ FarooqDrive کوئی درمیانی فائل ذخیرہ کرنے والا سرور استعمال نہیں کرتا۔'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse('https://www.mymandoob.com/farooqdrive/'), mode: LaunchMode.platformDefault, webOnlyWindowName: '_blank'),
            icon: const Icon(Icons.language),
            label: const Text('FarooqDrive'),
          ),
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse('mailto:support@mymandoob.com')),
            icon: const Icon(Icons.support_agent),
            label: const Text('Support'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final automaticSidebar = width >= 1360;
    final showSidebar =
        shouldShowDriveSidebar(width, pinned: _sidebarPinned);
    return Scaffold(
      drawer: !showSidebar
          ? Drawer(
              child: _Sidebar(
                controller: controller,
                onAddAccount: _addAccount,
                onSettings: _settings,
                onHelp: _showHelp,
                pinned: false,
                showPin: true,
                closeAfterSelection: true,
                onPinnedChanged: _setSidebarPinned,
              ),
            )
          : null,
      body: Stack(
        children: [
          SafeArea(
            child: Row(
              children: [
            if (showSidebar)
              SizedBox(
                width: 270,
                child: _Sidebar(
                  controller: controller,
                  onAddAccount: _addAccount,
                  onSettings: _settings,
                  onHelp: _showHelp,
                  pinned: _sidebarPinned,
                  showPin: !automaticSidebar,
                  closeAfterSelection: false,
                  onPinnedChanged: _setSidebarPinned,
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .65),
                    child: SingleChildScrollView(child: Column(children: [
                  _Header(
                    controller: controller,
                    showMenu: !showSidebar,
                    onActivity: _showActivityLog,
                  ),
                  if (controller.loading) const LinearProgressIndicator(),
                  _StorageSummary(controller: controller),
                  _NavigationBar(controller: controller),
                  _Toolbar(
                    controller: controller,
                    onUpload: _upload,
                    onNewFolder: () async {
                      final name = await _ask('New folder');
                      if (name != null && name.isNotEmpty) {
                        await controller.createFolder(name);
                      }
                    },
                    onRename: () async {
                      final item = controller.selectedItems.single;
                      final name = await _ask('Rename', initial: item.name);
                      if (name != null && name.isNotEmpty) {
                        await controller.renameSelected(name);
                      }
                    },
                    onTrash: () async {
                      if (await _confirm(
                        'Move to Trash?',
                        'The selected items will be moved to their provider Trash or Recycle Bin.',
                      )) {
                        await controller.trashSelected();
                      }
                    },
                    onDownload: _download,
                  ),
                  _FileViews(controller: controller),
                  if (controller.supportsMicrosoft) Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Tooltip(message: TransferSpool.cachePath, child: const Text(
                      'Cloud transfers use temporary disk space and extra verification downloads. Private limit: 1 GiB/file. See Help for cleanup and limits.',
                      style: TextStyle(fontSize: 11)))),
                  if (controller.transferResult.isNotEmpty) Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: SelectableText(controller.transferResult, style: const TextStyle(fontSize: 12))),
                    ])),
                  ),
                  Expanded(child: _FileList(controller: controller)),
                ],
              ),
            ),
              ],
            ),
          ),
          if (controller.loading || controller.indexing)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0x33000000),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 22,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                          const SizedBox(width: 16),
                          Flexible(child: Text(
                            controller.indexing
                                ? 'Scanning all Drives and folders…'
                                : controller.operationMessage,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          )),
                          if (controller.transferActive) TextButton(onPressed: controller.cancelTransfer, child: const Text('Cancel transfer')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(text),
          ],
        ),
      );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.controller,
    required this.onAddAccount,
    required this.onSettings,
    required this.onHelp,
    required this.pinned,
    required this.showPin,
    required this.closeAfterSelection,
    required this.onPinnedChanged,
  });
  final DriveController controller;
  final VoidCallback onAddAccount;
  final VoidCallback onSettings;
  final VoidCallback onHelp;
  final bool pinned;
  final bool showPin;
  final bool closeAfterSelection;
  final ValueChanged<bool> onPinnedChanged;

  void _selectDrive(BuildContext context, String? accountId) {
    controller.selectAccount(accountId);
    if (closeAfterSelection) Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xff0b1d31),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.memory(
                      base64Decode(officialFarooqDriveIconBase64),
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const CircleAvatar(
                        backgroundColor: Color(0xff278cff),
                        child:
                            Text('FD', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FarooqDrive',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                          ),
                        ),
                        Text(
                          'Version 21.1 Test',
                          style: TextStyle(
                            color: Color(0xff9db5d1),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showPin)
                    IconButton(
                      tooltip: pinned
                          ? 'Unpin Drives menu'
                          : 'Pin Drives menu open',
                      color: const Color(0xff9db5d1),
                      selectedIcon: const Icon(Icons.push_pin),
                      isSelected: pinned,
                      icon: const Icon(Icons.push_pin_outlined),
                      onPressed: () {
                        final next = !pinned;
                        onPinnedChanged(next);
                        if (next && closeAfterSelection) {
                          Navigator.maybePop(context);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 28),
              _DriveTile(
                title: 'All Drives',
                subtitle: 'Unified view',
                quota: controller.totalStorageLimit == null
                    ? '${_formatBytes(controller.totalStorageUsed)} used'
                    : '${_formatBytes(controller.totalStorageUsed)} / ${_formatCombinedCapacity(controller.accounts)} total',
                selected: controller.allDrives,
                onTap: () => _selectDrive(context, null),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 24, 12, 10),
                child: Text(
                  'CLOUD ACCOUNTS',
                  style: TextStyle(color: Color(0xff8da5c1), fontSize: 12),
                ),
              ),
              Expanded(
                child: ListView(
                  children: controller.accounts
                      .map((account) => DriveTree(key: ValueKey(account.id), controller: controller, account: account, child: _DriveTile(
                            title: '${account.provider == CloudProviderType.onedrive ? 'OneDrive · ' : 'Google · '}${account.name}',
                            subtitle: account.email,
                            subtitleColor:
                                _accountColor(controller, account.id),
                            quota: account.storageLimit == null
                                ? '${_formatBytes(account.storageUsed)} used'
                                : '${_formatBytes(account.storageUsed)} / ${_formatBytes(account.storageLimit!)}',
                            selected:
                                controller.selectedAccountId == account.id,
                            onTap: () => _selectDrive(context, account.id),
                            onDisconnect: () async {
                              final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Disconnect Drive?'),
                                      content: Text(
                                        'Disconnect ${account.email} from FarooqDrive? Your cloud files will not be deleted.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Disconnect'),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                              if (confirmed) {
                                await controller.disconnectAccount(account.id);
                              }
                            },
                          )))
                      .toList(),
                ),
              ),
              FilledButton.icon(
                onPressed: controller.loading ? null : () {
                  if (closeAfterSelection) Scaffold.of(context).closeDrawer();
                  onAddAccount();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add account'),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Account settings',
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings, color: Color(0xff9db5d1)),
                  ),
                  IconButton(
                    tooltip: 'Help — How FarooqDrive works',
                    onPressed: onHelp,
                    icon: const Icon(Icons.help_outline, color: Color(0xff9db5d1)),
                  ),
                  IconButton(
                    tooltip: 'FarooqDrive website',
                    onPressed: () => launchUrl(
                      Uri.parse('https://www.mymandoob.com/farooqdrive/'),
                      mode: LaunchMode.platformDefault,
                      webOnlyWindowName: '_blank',
                    ),
                    icon: const Icon(Icons.language, color: Color(0xff9db5d1)),
                  ),
                  IconButton(
                    tooltip: 'Contact support: support@mymandoob.com',
                    onPressed: () => launchUrl(
                      Uri.parse('mailto:support@mymandoob.com'),
                    ),
                    icon: const Icon(
                      Icons.support_agent,
                      color: Color(0xff9db5d1),
                    ),
                  ),
                  TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse('https://www.farooqmusic.com/'),
                      mode: LaunchMode.platformDefault,
                      webOnlyWindowName: '_blank',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xff9db5d1),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const Text(
                      'Design By',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _DriveTile extends StatelessWidget {
  const _DriveTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.subtitleColor,
    this.quota,
    this.onDisconnect,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color? subtitleColor;
  final String? quota;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) => ListTile(
        selected: selected,
        selectedTileColor: const Color(0xff203a57),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: subtitleColor ?? const Color(0xff9db5d1)),
            ),
            if (quota != null)
              Text(
                quota!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xff9db5d1), fontSize: 12),
              ),
          ],
        ),
        trailing: onDisconnect == null
            ? null
            : IconButton(
                tooltip: 'Disconnect Drive',
                onPressed: onDisconnect,
                icon: const Icon(Icons.link_off, color: Color(0xffff8a80)),
              ),
        onTap: onTap,
      );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.showMenu,
    required this.onActivity,
  });
  final DriveController controller;
  final bool showMenu;
  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          children: [
            Row(
              children: [
                if (showMenu)
                  Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Open Drives menu',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu),
                    ),
                  ),
                Expanded(
                  child: Text(
                    controller.allDrives
                        ? 'All Drives'
                        : controller.selectedAccount?.name ?? 'FarooqDrive',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff0b1d31),
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Activity — last 7 days',
                  onPressed: onActivity,
                  icon: Badge(
                    isLabelVisible: controller.activityLog.isNotEmpty,
                    label: Text('${controller.activityLog.length}'),
                    child: const Icon(Icons.history),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: controller.allDrives
                    ? const Color(0xffe8f0fe)
                    : _accountColor(controller, controller.selectedAccountId!)
                        .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: controller.allDrives
                  ? const Text(
                      'You are working across all connected Drives',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    )
                  : Text.rich(
                      TextSpan(
                        text: 'You are working on:  ',
                        children: [
                          TextSpan(
                            text: controller.selectedAccount!.email,
                            style: TextStyle(
                              color: _accountColor(
                                controller,
                                controller.selectedAccountId!,
                              ),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      );
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({required this.controller});
  final DriveController controller;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xffdce3ed)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: controller.canGoBack ? controller.goBack : null,
              icon: const Icon(Icons.arrow_back),
            ),
            IconButton(
              tooltip: 'Up one folder',
              onPressed: controller.canGoUp ? controller.goUp : null,
              icon: const Icon(Icons.arrow_upward),
            ),
            const SizedBox(
              height: 28,
              child: VerticalDivider(width: 12),
            ),
            if (controller.allDrives)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'All Drives',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var index = 0;
                          index < controller.currentPath.length;
                          index++) ...[
                        TextButton(
                          onPressed: () => controller.openCrumb(index),
                          child: Text(controller.currentPath[index].name),
                        ),
                        if (index < controller.currentPath.length - 1)
                          const Icon(Icons.chevron_right, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

class _StorageSummary extends StatelessWidget {
  const _StorageSummary({required this.controller});
  final DriveController controller;

  @override
  Widget build(BuildContext context) {
    final accounts = controller.allDrives
        ? controller.accounts
        : [if (controller.selectedAccount != null) controller.selectedAccount!];
    if (accounts.isEmpty) return const SizedBox.shrink();

    final used = accounts.fold<int>(0, (total, item) => total + item.storageUsed);
    final limitsKnown = accounts.every((item) => item.storageLimit != null);
    final limit = limitsKnown
        ? accounts.fold<int>(0, (total, item) => total + item.storageLimit!)
        : null;
    final free = limit == null ? null : (limit - used).clamp(0, limit);
    final indexedBytes = controller.indexedBytesFor(accounts);

    final cards = <Widget>[
          _StorageCard(
            icon: Icons.cloud_outlined,
            label: controller.allDrives ? 'Total capacity' : 'Drive capacity',
            value: limit == null
                ? 'Not reported'
                : controller.allDrives
                    ? '${_formatCombinedCapacity(accounts)} · ${accounts.length} Drives'
                    : _formatBytes(limit),
          ),
          const SizedBox(width: 10),
          _StorageCard(
            icon: Icons.data_usage,
            label: controller.allDrives ? 'Cloud storage used' : '${controller.selectedAccount?.provider == CloudProviderType.onedrive ? 'OneDrive' : 'Google Drive'} used',
            value: _formatBytes(used),
          ),
          const SizedBox(width: 10),
          _StorageCard(
            icon: Icons.calculate_outlined,
            label: 'Owned files indexed',
            value: controller.indexReady
                ? _formatBytes(indexedBytes)
                : controller.indexing ? 'Scanning…' : 'Not scanned',
          ),
          const SizedBox(width: 10),
          _StorageCard(
            icon: Icons.cloud_done_outlined,
            label: 'Free',
            value: free == null ? 'Not reported' : _formatBytes(free),
          ),
        ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Row(
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  Expanded(child: cards[index]),
                  if (index < cards.length - 1) const SizedBox(width: 10),
                ],
              ],
            );
          }
          final cardWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 8,
            children: cards
                .map((card) => SizedBox(width: cardWidth, child: card))
                .toList(),
          );
        },
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xffdce3ed)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xff0b67d1)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                    Text(value,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
      );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.onUpload,
    required this.onNewFolder,
    required this.onRename,
    required this.onTrash,
    required this.onDownload,
  });
  final DriveController controller;
  final VoidCallback onUpload;
  final VoidCallback onNewFolder;
  final VoidCallback onRename;
  final VoidCallback onTrash;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final count = controller.selectedItems.length;
    final hasDrive = controller.selectedAccount != null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffdce3ed)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.tonalIcon(
            onPressed: hasDrive ? onNewFolder : null,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('New folder'),
          ),
          FilledButton.tonalIcon(
            onPressed: hasDrive ? onUpload : null,
            icon: const Icon(Icons.upload),
            label: const Text('Upload'),
          ),
          TextButton.icon(
            onPressed: count > 0 ? onDownload : null,
            icon: const Icon(Icons.download),
            label: const Text('Download'),
          ),
          TextButton.icon(
            onPressed: count > 0
                ? () => controller.setClipboard(ClipboardMode.copy)
                : null,
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy'),
          ),
          TextButton.icon(
            onPressed: count > 0
                ? () => controller.setClipboard(ClipboardMode.move)
                : null,
            icon: const Icon(Icons.content_cut),
            label: const Text('Cut'),
          ),
          TextButton.icon(
            onPressed: hasDrive && controller.clipboard != null
                ? controller.paste
                : null,
            icon: const Icon(Icons.content_paste),
            label: const Text('Paste'),
          ),
          TextButton.icon(
            onPressed: count == 1 ? onRename : null,
            icon: const Icon(Icons.drive_file_rename_outline),
            label: const Text('Rename'),
          ),
          TextButton.icon(
            onPressed: count > 0 ? onTrash : null,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Trash'),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
          DropdownButton<String>(
            value: controller.sort,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'name', child: Text('Name')),
              DropdownMenuItem(value: 'modified', child: Text('Modified')),
              DropdownMenuItem(value: 'size', child: Text('Size')),
              DropdownMenuItem(value: 'type', child: Text('Type')),
            ],
            onChanged: (value) {
              if (value != null) controller.setSort(value);
            },
          ),
        ],
      ),
    );
  }
}

class _FileViews extends StatelessWidget {
  const _FileViews({required this.controller});
  final DriveController controller;

  @override
  Widget build(BuildContext context) {
    final tabs = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DropdownButton<String>(value: controller.layout,
                onChanged: (value) { if (value != null) controller.setLayout(value); },
                items: const [DropdownMenuItem(value: 'details', child: Text('Details')),
                  DropdownMenuItem(value: 'list', child: Text('List')),
                  DropdownMenuItem(value: 'icons', child: Text('Large icons'))]),
              ChoiceChip(
                avatar: const Icon(Icons.select_all_outlined, size: 18),
                label: Text('All (${controller.allItemCount})'),
                selected: controller.viewMode == FileViewMode.all,
                onSelected: (_) => controller.setViewMode(FileViewMode.all),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.folder_outlined, size: 18),
                label: Text('Folders (${controller.folderCount})'),
                selected: controller.viewMode == FileViewMode.folders,
                onSelected: (_) => controller.setViewMode(FileViewMode.folders),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.insert_drive_file_outlined, size: 18),
                label: Text('Files (${controller.fileCount})'),
                selected: controller.viewMode == FileViewMode.files,
                onSelected: (_) => controller.setViewMode(FileViewMode.files),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.content_copy, size: 18),
                label: Text(controller.indexing
                    ? 'Scanning all folders…'
                    : controller.indexReady
                        ? 'Exact duplicates (${controller.exactDuplicateCount})'
                        : 'Scan exact duplicates'),
                selected: controller.viewMode == FileViewMode.exactDuplicates,
                onSelected: (_) =>
                    controller.setViewMode(FileViewMode.exactDuplicates),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.difference_outlined, size: 18),
                label: Text(controller.indexing
                    ? 'Scanning all folders…'
                    : controller.indexReady
                        ? 'Same name, different size (${controller.nameConflictCount})'
                        : 'Scan same-name files'),
                selected: controller.viewMode == FileViewMode.nameConflicts,
                onSelected: (_) =>
                    controller.setViewMode(FileViewMode.nameConflicts),
              ),
            ],
          );
    final search = TextField(
      onChanged: controller.setQuery,
      decoration: InputDecoration(
        hintText: 'Search all Drives',
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffdce3ed)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffdce3ed)),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 1050
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: tabs),
                  const SizedBox(width: 12),
                  SizedBox(width: 310, child: search),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tabs,
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: search),
                ],
              ),
      ),
    );
  }
}

class _FileList extends StatefulWidget {
  const _FileList({required this.controller});
  final DriveController controller;

  @override
  State<_FileList> createState() => _FileListState();
}

class _FileListState extends State<_FileList> {
  DriveController get controller => widget.controller;
  final ScrollController _horizontalScroll = ScrollController();

  Widget _transferRow(DriveItem item, Widget child) {
    final draggable = CloudDragSource(controller: controller, item: item, child: child);
    if (!item.isFolder) return draggable;
    final account = controller.accountById(item.accountId)!;
    final api = controller.apiFor(account);
    final path = controller.allDrives
        ? [FolderCrumb(api.rootFolderId, api.rootFolderLabel)]
        : controller.currentPath;
    return CloudDropTarget(controller: controller, accountId: item.accountId,
      path: [...path, FolderCrumb(item.id, item.name)], child: draggable);
  }

  double nameWidth = 380;
  double accountWidth = 240;
  double locationWidth = 320;
  double sizeWidth = 100;
  double modifiedWidth = 180;

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  Widget _header(String label, double width, ValueChanged<double> resize) =>
      SizedBox(
        width: width,
        child: Row(
          children: [
            Expanded(child: Text(label)),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) =>
                    setState(() => resize(details.delta.dx)),
                child: const SizedBox(
                  width: 12,
                  height: 36,
                  child: VerticalDivider(width: 12),
                ),
              ),
            ),
          ],
        ),
      );

  static String size(int? bytes) {
    if (bytes == null) return '—';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var amount = bytes.toDouble();
    var unit = 0;
    while (amount >= 1024 && unit < units.length - 1) {
      amount /= 1024;
      unit++;
    }
    return '${unit == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(1)} ${units[unit]}';
  }

  Future<void> _openItem(BuildContext context, DriveItem item) async {
    if (item.isFolder) {
      await controller.openFolder(item);
      return;
    }
    final link = item.webViewLink;
    if (link == null || link.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Drive did not provide an open link.')),
        );
      }
      return;
    }
    final opened = await launchUrl(
      Uri.parse(link),
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (opened) await controller.recordFileOpened(item);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The file could not be opened. Allow pop-ups and try again.')),
      );
    }
  }

  Future<void> _downloadItem(DriveItem item) async {
    if (item.isFolder) return;
    if (item.mimeType.startsWith('application/vnd.google-apps.')) {
      final link = item.webViewLink;
      if (link != null) {
        await launchUrl(
          Uri.parse(link),
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        );
      }
      return;
    }
    final bytes = await controller.download(item);
    final dot = item.name.lastIndexOf('.');
    await FileSaver.instance.saveFile(
      name: dot > 0 ? item.name.substring(0, dot) : item.name,
      bytes: bytes,
      ext: dot > 0 ? item.name.substring(dot + 1) : '',
      mimeType: MimeType.other,
      customMimeType: item.mimeType,
    );
  }

  Future<void> _renameItem(BuildContext context, DriveItem item) async {
    final input = TextEditingController(text: item.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: input, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == item.name) return;
    controller.selectOnly(item);
    await controller.renameSelected(name);
  }

  Future<void> _deleteItem(BuildContext context, DriveItem item) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Move to Trash?'),
            content: Text('${item.name} will be moved to Google Drive Trash.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Move to Trash'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    controller.selectOnly(item);
    await controller.trashSelected();
  }

  Future<void> _moveItem(BuildContext context, DriveItem item) async {
    final destination = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Move to Drive'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Choose the destination My Drive.'),
          ),
          for (final account in controller.accounts)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, account.id),
              child: Row(
                children: [
                  Icon(Icons.cloud, color: _accountColor(controller, account.id)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(account.email)),
                ],
              ),
            ),
        ],
      ),
    );
    if (destination != null) {
      await controller.moveItemToDriveRoot(item, destination);
    }
  }

  Future<void> _runMenuAction(
    BuildContext context,
    DriveItem item,
    _ItemAction action,
  ) async {
    switch (action) {
      case _ItemAction.open:
        await _openItem(context, item);
        return;
      case _ItemAction.copy:
        controller.setClipboardItem(ClipboardMode.copy, item);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied. Open a destination Drive or folder and press Paste.'),
          ),
        );
        return;
      case _ItemAction.cut:
        controller.setClipboardItem(ClipboardMode.move, item);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cut. Open a destination Drive or folder and press Paste.',
            ),
          ),
        );
        return;
      case _ItemAction.move:
        await _moveItem(context, item);
        return;
      case _ItemAction.rename:
        await _renameItem(context, item);
        return;
      case _ItemAction.delete:
        await _deleteItem(context, item);
        return;
      case _ItemAction.download:
        await _downloadItem(item);
        return;
      case _ItemAction.paste:
        await controller.pasteIntoFolder(item);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = controller.visibleFiles;
    if (files.isEmpty) {
      return Center(
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open, size: 54, color: Color(0xff8ba0b8)),
            const SizedBox(height: 12),
            Text(
              controller.accounts.isEmpty
                  ? 'Connect a cloud account to begin.'
                  : controller.viewMode == FileViewMode.all
                      ? 'No files or folders in this location.'
                      : controller.viewMode == FileViewMode.files
                      ? 'No files in this folder.'
                      : controller.viewMode == FileViewMode.folders
                          ? 'No folders in this location.'
                          : 'No matching duplicates were found across your Drives.',
            ),
          ],
        )),
      );
    }
    if (controller.layout != 'details') {
      Widget tile(DriveItem item) => _transferRow(item, Card(
        color: controller.selectedKeys.contains(controller.keyOf(item)) ? const Color(0xffdce8ff) : null,
        child: InkWell(onTap: () => controller.selectOnly(item),
          onDoubleTap: () => _openItem(context, item),
          onSecondaryTap: () async {
            final action = await showDialog<_ItemAction>(context: context, builder: (context) => SimpleDialog(
              title: Text(item.name), children: [for (final entry in <_ItemAction, String>{
                _ItemAction.open: 'Open', _ItemAction.copy: 'Copy', _ItemAction.cut: 'Cut',
                if (item.isFolder) _ItemAction.paste: 'Paste here', _ItemAction.rename: 'Rename', _ItemAction.delete: 'Trash',
              }.entries) SimpleDialogOption(onPressed: () => Navigator.pop(context, entry.key), child: Text(entry.value))]));
            if (action != null && context.mounted) await _runMenuAction(context, item, action);
          },
          child: controller.layout == 'list' ? ListTile(
            leading: Checkbox(value: controller.selectedKeys.contains(controller.keyOf(item)), onChanged: (value) => controller.toggle(item, value ?? false)),
            title: Text(item.name), subtitle: Text(item.accountEmail), trailing: Text(size(controller.sizeOf(item))))
          : Padding(padding: const EdgeInsets.all(8), child: Column(children: [
              Row(children: [Checkbox(value: controller.selectedKeys.contains(controller.keyOf(item)), onChanged: (value) => controller.toggle(item, value ?? false)),
                NativeFileIcon(fileName: item.name, isFolder: item.isFolder, size: 42)]),
              Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(item.accountEmail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
            ]))),
      ));
      return Padding(padding: const EdgeInsets.all(16), child: controller.layout == 'list'
        ? ListView.builder(itemCount: files.length, itemBuilder: (context, index) => tile(files[index]))
        : GridView.builder(gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, mainAxisExtent: 150),
          itemCount: files.length, itemBuilder: (context, index) => tile(files[index])));
    }
    final allSelected =
        files.every((item) => controller.selectedKeys.contains(controller.keyOf(item)));
    final showLocation =
        controller.viewMode == FileViewMode.exactDuplicates ||
            controller.viewMode == FileViewMode.nameConflicts;
    final requiredWidth = nameWidth +
        accountWidth +
        (showLocation ? locationWidth : 0) +
        sizeWidth +
        modifiedWidth +
        72;
    return Card(
      margin: const EdgeInsets.all(20),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = requiredWidth > constraints.maxWidth
              ? requiredWidth
              : constraints.maxWidth;
          return Scrollbar(
            controller: _horizontalScroll,
            thumbVisibility: true,
            notificationPredicate: (notification) => notification.depth == 1,
            child: SingleChildScrollView(
              controller: _horizontalScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                height: constraints.maxHeight,
                child: ListView(
                  children: [
          Container(
            color: const Color(0xffeef3f9),
            child: ListTile(
              leading: Checkbox(
                value: allSelected,
                onChanged: (value) => controller.toggleAll(value ?? false),
              ),
              title: Row(
                children: [
                  _header('Name', nameWidth, (delta) {
                    nameWidth = (nameWidth + delta).clamp(180, 900).toDouble();
                  }),
                  _header('Account', accountWidth, (delta) {
                    accountWidth =
                        (accountWidth + delta).clamp(150, 600).toDouble();
                  }),
                  if (controller.viewMode == FileViewMode.exactDuplicates ||
                      controller.viewMode == FileViewMode.nameConflicts)
                    _header('Location', locationWidth, (delta) {
                      locationWidth =
                          (locationWidth + delta).clamp(200, 900).toDouble();
                    }),
                  _header('Size', sizeWidth, (delta) {
                    sizeWidth = (sizeWidth + delta).clamp(90, 260).toDouble();
                  }),
                  _header('Modified', modifiedWidth, (delta) {
                    modifiedWidth =
                        (modifiedWidth + delta).clamp(150, 420).toDouble();
                  }),
                ],
              ),
            ),
          ),
          for (final item in files)
            _transferRow(item, Column(
              children: [
                ListTile(
                  dense: true,
                  minVerticalPadding: 4,
                  visualDensity: const VisualDensity(vertical: -1),
                  leading: Checkbox(
                    value: controller.selectedKeys.contains(controller.keyOf(item)),
                    onChanged: (value) => controller.toggle(item, value ?? false),
                  ),
                  title: Row(
                    children: [
                      NativeFileIcon(
                        fileName: item.name,
                        isFolder: item.isFolder,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: nameWidth - 80,
                        child: Tooltip(
                          message: '${item.location} / ${item.name}',
                          waitDuration: const Duration(milliseconds: 350),
                          child: InkWell(
                            onTap: () => _openItem(context, item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xff174ea6),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (controller.isExactDuplicate(item))
                                  const Text(
                                    'Exact duplicate on another Drive',
                                    style: TextStyle(
                                      color: Color(0xffb3261e),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else if (controller.isNameConflict(item))
                                  const Text(
                                    'Same name, different size',
                                    style: TextStyle(
                                      color: Color(0xff9a5b00),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      PopupMenuButton<_ItemAction>(
                        tooltip: 'File and folder actions',
                        icon: const Icon(Icons.more_vert),
                        onSelected: (action) =>
                            _runMenuAction(context, item, action),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: _ItemAction.open,
                            child: ListTile(
                              leading: Icon(Icons.open_in_new),
                              title: Text('Open'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: _ItemAction.copy,
                            child: ListTile(
                              leading: Icon(Icons.copy_outlined),
                              title: Text('Copy'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: _ItemAction.cut,
                            child: ListTile(
                              leading: Icon(Icons.content_cut),
                              title: Text('Cut'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: _ItemAction.move,
                            child: ListTile(
                              leading: Icon(Icons.drive_file_move_outline),
                              title: Text('Move to…'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: _ItemAction.rename,
                            child: ListTile(
                              leading: Icon(Icons.drive_file_rename_outline),
                              title: Text('Rename'),
                            ),
                          ),
                          PopupMenuItem(
                            value: _ItemAction.download,
                            enabled: !item.isFolder,
                            child: const ListTile(
                              leading: Icon(Icons.download),
                              title: Text('Download'),
                            ),
                          ),
                          PopupMenuItem(
                            value: _ItemAction.paste,
                            enabled: item.isFolder && controller.clipboard != null,
                            child: const ListTile(
                              leading: Icon(Icons.content_paste),
                              title: Text('Paste into folder'),
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: _ItemAction.delete,
                            child: ListTile(
                              leading: Icon(Icons.delete_outline, color: Colors.red),
                              title: Text('Move to Trash'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: accountWidth,
                        child: Tooltip(
                          message: item.accountEmail,
                          waitDuration: const Duration(milliseconds: 350),
                          child: Text(
                            item.accountEmail,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _accountColor(controller, item.accountId),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      if (controller.viewMode == FileViewMode.exactDuplicates ||
                          controller.viewMode == FileViewMode.nameConflicts)
                        SizedBox(
                          width: locationWidth,
                          child: Tooltip(
                            message: '${item.location} / ${item.name}',
                            waitDuration: const Duration(milliseconds: 350),
                            child: Text(
                              item.location,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      SizedBox(
                        width: sizeWidth,
                        child: Tooltip(
                          message: size(controller.sizeOf(item)),
                          child: Text(
                            size(controller.sizeOf(item)),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: modifiedWidth,
                        child: Tooltip(
                          message: item.modifiedTime == null
                              ? '—'
                              : DateFormat.yMMMd().add_jms().format(item.modifiedTime!.toLocal()),
                          child: Text(
                            item.modifiedTime == null
                                ? '—'
                                : DateFormat.yMMMd().add_jm().format(item.modifiedTime!.toLocal()),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => controller.toggle(
                    item,
                    !controller.selectedKeys.contains(controller.keyOf(item)),
                  ),
                  onLongPress: () => _openItem(context, item),
                ),
                const Divider(height: 1),
              ],
            )),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _ItemAction { open, copy, cut, move, rename, delete, download, paste }
