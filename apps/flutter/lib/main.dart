import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'drive_controller.dart';
import 'google_auth.dart';
import 'models.dart';
import 'native_file_icon.dart';
import 'official_icon_data.dart';

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

void main() => runApp(const FarooqDriveApp());

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

  @override
  void initState() {
    super.initState();
    controller.addListener(_changed);
    controller.initialize();
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
  }

  Future<void> _addAccount() async {
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

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 850;
    return Scaffold(
      drawer: compact
          ? Drawer(
              child: _Sidebar(
                controller: controller,
                onAddAccount: _addAccount,
                onSettings: _settings,
              ),
            )
          : null,
      body: Stack(
        children: [
          SafeArea(
            child: Row(
              children: [
            if (!compact)
              SizedBox(
                width: 270,
                child: _Sidebar(
                  controller: controller,
                  onAddAccount: _addAccount,
                  onSettings: _settings,
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  _Header(
                    controller: controller,
                    showMenu: compact,
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
                        'The selected items will be moved to Google Drive Trash.',
                      )) {
                        await controller.trashSelected();
                      }
                    },
                    onDownload: _download,
                  ),
                  _FileViews(controller: controller),
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
                          Text(
                            controller.indexing
                                ? 'Scanning all Drives and folders…'
                                : controller.operationMessage,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
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

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.controller,
    required this.onAddAccount,
    required this.onSettings,
  });
  final DriveController controller;
  final VoidCallback onAddAccount;
  final VoidCallback onSettings;

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
                            fontWeight: FontWeight.w800,
                            fontSize: 21,
                          ),
                        ),
                        Text(
                          'Version 16',
                          style: TextStyle(
                            color: Color(0xff9db5d1),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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
                onTap: () => controller.selectAccount(null),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 24, 12, 10),
                child: Text(
                  'GOOGLE ACCOUNTS',
                  style: TextStyle(color: Color(0xff8da5c1), fontSize: 12),
                ),
              ),
              Expanded(
                child: ListView(
                  children: controller.accounts
                      .map((account) => _DriveTile(
                            title: account.name,
                            subtitle: account.email,
                            subtitleColor:
                                _accountColor(controller, account.id),
                            quota: account.storageLimit == null
                                ? '${_formatBytes(account.storageUsed)} used'
                                : '${_formatBytes(account.storageUsed)} / ${_formatBytes(account.storageLimit!)}',
                            selected:
                                controller.selectedAccountId == account.id,
                            onTap: () => controller.selectAccount(account.id),
                            onDisconnect: () async {
                              final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Disconnect Drive?'),
                                      content: Text(
                                        'Disconnect ${account.email} from FarooqDrive? Your Google Drive files will not be deleted.',
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
                          ))
                      .toList(),
                ),
              ),
              FilledButton.icon(
                onPressed: controller.loading ? null : onAddAccount,
                icon: const Icon(Icons.add),
                label: const Text('Add Google account'),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Google settings',
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings, color: Color(0xff9db5d1)),
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
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu),
                    ),
                  ),
                Expanded(
                  child: Text(
                    controller.allDrives
                        ? 'All Drives'
                        : controller.selectedAccount?.name ?? 'FarooqDrive',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
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
                SizedBox(
                  width: showMenu ? 200 : 310,
                  child: SearchBar(
                    leading: const Icon(Icons.search),
                    hintText: 'Search all Drives',
                    onChanged: controller.setQuery,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
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
            label: 'Google Drive used',
            value: _formatBytes(used),
          ),
          const SizedBox(width: 10),
          _StorageCard(
            icon: Icons.calculate_outlined,
            label: 'Owned files indexed',
            value: controller.indexReady
                ? _formatBytes(indexedBytes)
                : 'Calculating…',
          ),
          const SizedBox(width: 10),
          _StorageCard(
            icon: Icons.cloud_done_outlined,
            label: 'Free',
            value: free == null ? 'Not reported' : _formatBytes(free),
          ),
        ],
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
  Widget build(BuildContext context) => Expanded(
        child: Container(
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
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
          ),
        ),
      );
}

class _FileList extends StatelessWidget {
  const _FileList({required this.controller});
  final DriveController controller;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open, size: 54, color: Color(0xff8ba0b8)),
            const SizedBox(height: 12),
            Text(
              controller.accounts.isEmpty
                  ? 'Connect a Google account to begin.'
                  : controller.viewMode == FileViewMode.files
                      ? 'No files in this folder.'
                      : controller.viewMode == FileViewMode.folders
                          ? 'No folders in this location.'
                          : 'No matching duplicates were found across your Drives.',
            ),
          ],
        ),
      );
    }
    final allSelected =
        files.every((item) => controller.selectedKeys.contains(controller.keyOf(item)));
    return Card(
      margin: const EdgeInsets.all(20),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
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
                  const Expanded(flex: 4, child: Text('Name')),
                  const Expanded(flex: 3, child: Text('Account')),
                  if (controller.viewMode == FileViewMode.exactDuplicates ||
                      controller.viewMode == FileViewMode.nameConflicts)
                    const Expanded(flex: 3, child: Text('Location')),
                  const Expanded(child: Text('Size')),
                  const Expanded(flex: 2, child: Text('Modified')),
                ],
              ),
            ),
          ),
          for (final item in files)
            Column(
              children: [
                ListTile(
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
                      Expanded(
                        flex: 4,
                        child: InkWell(
                          onTap: () => _openItem(context, item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xff174ea6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (controller.isExactDuplicate(item))
                                  const Text(
                                    'Exact duplicate on another Drive',
                                    style: TextStyle(
                                      color: Color(0xffb3261e),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                else if (controller.isNameConflict(item))
                                  const Text(
                                    'Same name, different size',
                                    style: TextStyle(
                                      color: Color(0xff9a5b00),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
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
                      Expanded(
                        flex: 3,
                        child: Text(
                          item.accountEmail,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _accountColor(controller, item.accountId),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (controller.viewMode == FileViewMode.exactDuplicates ||
                          controller.viewMode == FileViewMode.nameConflicts)
                        Expanded(
                          flex: 3,
                          child: Tooltip(
                            message: item.location,
                            child: Text(
                              item.location,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      Expanded(child: Text(size(controller.sizeOf(item)))),
                      Expanded(
                        flex: 2,
                        child: Text(item.modifiedTime == null
                            ? '—'
                            : DateFormat.yMMMd().add_jm().format(item.modifiedTime!.toLocal())),
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
            ),
        ],
      ),
    );
  }
}

enum _ItemAction { open, copy, cut, move, rename, delete, download, paste }
