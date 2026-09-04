import 'package:flutter/foundation.dart';

import 'google_auth.dart';
import 'google_drive_api.dart';
import 'models.dart';

class DriveController extends ChangeNotifier {
  DriveController({GoogleDriveApi? api, GoogleAccountAuthorizer? authorizer})
      : api = api ?? GoogleDriveApi(),
        authorizer = authorizer ?? GoogleAccountAuthorizer();

  final GoogleDriveApi api;
  final GoogleAccountAuthorizer authorizer;
  final List<DriveAccount> accounts = [];
  final List<DriveItem> files = [];
  final Set<String> selectedKeys = {};
  final Map<String, List<FolderCrumb>> paths = {};

  String? selectedAccountId;
  String query = '';
  String sort = 'name';
  DriveClipboard? clipboard;
  bool loading = false;
  String? error;

  bool get allDrives => selectedAccountId == null;
  DriveAccount? get selectedAccount => accountById(selectedAccountId);
  List<FolderCrumb> get currentPath => selectedAccountId == null
      ? const []
      : paths[selectedAccountId] ?? const [FolderCrumb('root', 'My Drive')];
  String get currentFolderId => currentPath.isEmpty ? 'root' : currentPath.last.id;

  DriveAccount? accountById(String? id) {
    if (id == null) return null;
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  String keyOf(DriveItem item) => '${item.accountId}:${item.id}';
  List<DriveItem> get selectedItems =>
      files.where((item) => selectedKeys.contains(keyOf(item))).toList();

  List<DriveItem> get visibleFiles {
    final normalized = query.trim().toLowerCase();
    final result = files
        .where((item) =>
            normalized.isEmpty || item.name.toLowerCase().contains(normalized))
        .toList();
    result.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return switch (sort) {
        'size' => (a.size ?? 0).compareTo(b.size ?? 0),
        'modified' => (b.modifiedTime ?? DateTime(0))
            .compareTo(a.modifiedTime ?? DateTime(0)),
        'type' => a.mimeType.compareTo(b.mimeType),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
    });
    return result;
  }

  Future<void> addAccount() => _guard(() async {
        final added = await authorizer.addAccount();
        if (added == null) return;
        final index = accounts.indexWhere((item) => item.id == added.id);
        if (index < 0) {
          accounts.add(added);
        } else {
          accounts[index] = added;
        }
        paths.putIfAbsent(
          added.id,
          () => const [FolderCrumb('root', 'My Drive')],
        );
        selectedAccountId = added.id;
        await _loadFiles();
      });

  Future<void> selectAccount(String? id) => _guard(() async {
        selectedAccountId = id;
        if (id != null) {
          paths.putIfAbsent(
            id,
            () => const [FolderCrumb('root', 'My Drive')],
          );
        }
        await _loadFiles();
      });

  Future<void> refresh() => _guard(_loadFiles);

  Future<void> _loadFiles() async {
    final targets = allDrives
        ? accounts
        : [if (selectedAccount != null) selectedAccount!];
    final groups = await Future.wait(targets.map((account) {
      final folder = allDrives
          ? 'root'
          : (paths[account.id] ??
                  const [FolderCrumb('root', 'My Drive')])
              .last
              .id;
      return api.listFolder(account, folder);
    }));
    files
      ..clear()
      ..addAll(groups.expand((group) => group));
    selectedKeys.clear();
  }

  Future<void> openFolder(DriveItem item) => _guard(() async {
        if (!item.isFolder) return;
        selectedAccountId = item.accountId;
        final path = paths.putIfAbsent(
          item.accountId,
          () => const [FolderCrumb('root', 'My Drive')],
        );
        path.add(FolderCrumb(item.id, item.name));
        await _loadFiles();
      });

  Future<void> openCrumb(int index) => _guard(() async {
        if (selectedAccountId == null) return;
        paths[selectedAccountId!] = currentPath.take(index + 1).toList();
        await _loadFiles();
      });

  Future<void> goUp() => _guard(() async {
        if (selectedAccountId == null || currentPath.length <= 1) return;
        paths[selectedAccountId!] =
            currentPath.take(currentPath.length - 1).toList();
        await _loadFiles();
      });

  void toggle(DriveItem item, bool value) {
    value ? selectedKeys.add(keyOf(item)) : selectedKeys.remove(keyOf(item));
    notifyListeners();
  }

  void toggleAll(bool value) {
    value
        ? selectedKeys.addAll(visibleFiles.map(keyOf))
        : selectedKeys.removeAll(visibleFiles.map(keyOf));
    notifyListeners();
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  void setSort(String value) {
    sort = value;
    notifyListeners();
  }

  void setClipboard(ClipboardMode mode) {
    if (selectedItems.isEmpty) return;
    clipboard = DriveClipboard(mode, List.of(selectedItems));
    notifyListeners();
  }

  Future<void> createFolder(String name) => _guard(() async {
        final account = selectedAccount;
        if (account == null) throw const DriveApiException('Open one Drive first.');
        await api.createFolder(account, currentFolderId, name.trim());
        await _loadFiles();
      });

  Future<void> renameSelected(String name) => _guard(() async {
        if (selectedItems.length != 1) return;
        final item = selectedItems.single;
        await api.rename(accountById(item.accountId)!, item.id, name.trim());
        await _loadFiles();
      });

  Future<void> trashSelected() => _guard(() async {
        for (final item in selectedItems) {
          await api.setTrashed(accountById(item.accountId)!, item.id, true);
        }
        await _loadFiles();
      });

  Future<void> upload(String name, Uint8List bytes, String? mimeType) =>
      _guard(() async {
        final account = selectedAccount;
        if (account == null) throw const DriveApiException('Open one Drive first.');
        await api.uploadBytes(
          account,
          parentId: currentFolderId,
          name: name,
          bytes: bytes,
          mimeType: mimeType ?? 'application/octet-stream',
        );
        await _loadFiles();
      });

  Future<Uint8List> download(DriveItem item) =>
      api.downloadBytes(accountById(item.accountId)!, item);

  Future<void> paste() => _guard(() async {
        final clip = clipboard;
        final destination = selectedAccount;
        if (clip == null || destination == null) {
          throw const DriveApiException('Open the destination folder first.');
        }
        for (final item in clip.items) {
          if (item.isFolder) {
            throw const DriveApiException(
              'Recursive folder transfer is not enabled in this milestone.',
            );
          }
          final source = accountById(item.accountId)!;
          if (source.id == destination.id) {
            clip.mode == ClipboardMode.copy
                ? await api.copy(source, item, currentFolderId)
                : await api.move(source, item, currentFolderId);
          } else {
            final bytes = await api.downloadBytes(source, item);
            await api.uploadBytes(
              destination,
              parentId: currentFolderId,
              name: item.name,
              bytes: bytes,
              mimeType: item.mimeType,
            );
            if (clip.mode == ClipboardMode.move) {
              await api.setTrashed(source, item.id, true);
            }
          }
        }
        if (clip.mode == ClipboardMode.move) clipboard = null;
        await _loadFiles();
      });

  Future<void> _guard(Future<void> Function() action) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on DriveApiException catch (exception) {
      error = exception.message;
    } catch (exception) {
      error = exception.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
