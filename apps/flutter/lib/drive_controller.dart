import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final List<DriveItem> indexedFiles = [];
  final Set<String> selectedKeys = {};
  final Map<String, List<FolderCrumb>> paths = {};
  final Map<String, int> folderSizes = {};
  final List<ActivityEntry> activityLog = [];
  final List<_NavigationState> _navigationHistory = [];

  String? selectedAccountId;
  String webClientId = '';
  String query = '';
  String sort = 'name';
  FileViewMode viewMode = FileViewMode.files;
  DriveClipboard? clipboard;
  bool loading = false;
  bool indexing = false;
  bool indexReady = false;
  String? error;
  String operationMessage = 'Working…';

  bool get allDrives => selectedAccountId == null;
  bool get canGoBack => _navigationHistory.isNotEmpty;
  bool get canGoUp => selectedAccountId != null && currentPath.length > 1;
  int get totalStorageUsed =>
      accounts.fold(0, (total, account) => total + account.storageUsed);
  int? get totalStorageLimit => accounts.every((item) => item.storageLimit != null)
      ? accounts.fold<int>(
          0,
          (total, account) => total + account.storageLimit!,
        )
      : null;
  int indexedBytesFor(Iterable<DriveAccount> targetAccounts) {
    final ids = targetAccounts.map((account) => account.id).toSet();
    return indexedFiles
        .where((item) =>
            ids.contains(item.accountId) && !item.isFolder && item.ownedByMe)
        .fold(0, (total, item) => total + (item.size ?? 0));
  }
  bool get hasClientId => webClientId.endsWith('.apps.googleusercontent.com');
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
  int? sizeOf(DriveItem item) =>
      item.isFolder ? folderSizes[keyOf(item)] : item.size;
  List<DriveItem> get selectedItems {
    final available = <String, DriveItem>{
      for (final item in files) keyOf(item): item,
      for (final item in indexedFiles) keyOf(item): item,
    };
    return selectedKeys.map((key) => available[key]).whereType<DriveItem>().toList();
  }

  List<DriveItem> get visibleFiles {
    final normalized = query
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[*?]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    final searchTerms = normalized.split(' ').where((item) => item.isNotEmpty);
    final duplicateView = viewMode == FileViewMode.exactDuplicates ||
        viewMode == FileViewMode.nameConflicts;
    final useGlobalIndex = duplicateView ||
        (normalized.isNotEmpty && indexReady);
    final source = useGlobalIndex ? indexedFiles : files;
    final searched = source.where((item) {
      if (normalized.isEmpty) return true;
      final searchable = <String>[
        item.name,
        item.accountEmail,
        item.location,
        item.mimeType,
        item.isFolder ? 'folder directory' : 'file',
        if (item.size != null) '${item.size}',
      ].join(' ').toLowerCase();
      return searchTerms.every(searchable.contains);
    }).toList();
    final result = searched.where((item) {
      return switch (viewMode) {
        FileViewMode.files => !item.isFolder,
        FileViewMode.folders => item.isFolder,
        FileViewMode.exactDuplicates => isExactDuplicate(item),
        FileViewMode.nameConflicts => isNameConflict(item),
      };
    }).toList();
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

  bool isExactDuplicate(DriveItem item) => !item.isFolder &&
      item.size != null &&
      indexedFiles.any((other) =>
      keyOf(other) != keyOf(item) &&
      !other.isFolder &&
      other.isFolder == item.isFolder &&
      other.name.trim().toLowerCase() == item.name.trim().toLowerCase() &&
      other.size == item.size);

  bool isNameConflict(DriveItem item) => !item.isFolder &&
      indexedFiles.any((other) =>
      keyOf(other) != keyOf(item) &&
      !other.isFolder &&
      other.isFolder == item.isFolder &&
      other.name.trim().toLowerCase() == item.name.trim().toLowerCase() &&
      (other.size != item.size || item.size == null || other.size == null));

  int get exactDuplicateCount =>
      indexedFiles.where(isExactDuplicate).map((item) => item.name.toLowerCase()).toSet().length;
  int get nameConflictCount =>
      indexedFiles.where(isNameConflict).map((item) => item.name.toLowerCase()).toSet().length;
  int get fileCount => files.where((item) => !item.isFolder).length;
  int get folderCount => files.where((item) => item.isFolder).length;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    webClientId = preferences.getString('farooqdrive.googleClientId') ??
        preferences.getString('farooqdrive.webClientId') ??
        '';
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    activityLog
      ..clear()
      ..addAll((preferences.getStringList('farooqdrive.activityLog') ?? const [])
          .map(ActivityEntry.tryFromJson)
          .whereType<ActivityEntry>()
          .where((entry) => entry.timestamp.isAfter(cutoff)));
    loading = true;
    operationMessage = 'Restoring Google accounts…';
    notifyListeners();
    try {
      final restored = await authorizer.restoreAccounts(webClientId);
      accounts
        ..clear()
        ..addAll(restored);
      for (final account in accounts) {
        paths[account.id] = <FolderCrumb>[
          const FolderCrumb('root', 'My Drive'),
        ];
      }
      if (accounts.isNotEmpty) {
        selectedAccountId = accounts.first.id;
        await _buildGlobalIndex();
        await _loadFiles();
      }
    } catch (exception) {
      error = 'Saved Google accounts could not be restored: $exception';
    } finally {
      loading = false;
      operationMessage = 'Working…';
      notifyListeners();
    }
  }

  Future<void> saveClientId(String value) async {
    final clientId = value.trim();
    if (!clientId.endsWith('.apps.googleusercontent.com')) {
      error = 'Enter a valid ${GoogleAccountAuthorizer.clientIdLabel}.';
      notifyListeners();
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('farooqdrive.googleClientId', clientId);
    webClientId = clientId;
    error = null;
    notifyListeners();
  }

  Future<void> addAccount() => _guard(() async {
        if (!hasClientId && GoogleAccountAuthorizer.buildClientId.isEmpty) {
          throw const DriveApiException(
            GoogleAccountAuthorizer.missingClientIdMessage,
          );
        }
        final added = await authorizer.addAccount(webClientId);
        if (added == null) return;
        final index = accounts.indexWhere((item) => item.id == added.id);
        if (index < 0) {
          accounts.add(added);
        } else {
          accounts[index] = added;
        }
        paths.putIfAbsent(
          added.id,
          () => <FolderCrumb>[const FolderCrumb('root', 'My Drive')],
        );
        selectedAccountId = added.id;
        indexReady = false;
        await _buildGlobalIndex();
        await _loadFiles();
        await _recordActivity(
          'Drive connected',
          added.email,
          accountEmail: added.email,
        );
      });

  Future<void> selectAccount(String? id) => _guard(() async {
        if (selectedAccountId != id) _rememberLocation();
        selectedAccountId = id;
        if (id != null) {
          paths.putIfAbsent(
            id,
            () => <FolderCrumb>[const FolderCrumb('root', 'My Drive')],
          );
        }
        if (id == null) await _refreshQuotas();
        if (!indexReady) await _buildGlobalIndex();
        await _loadFiles();
        if (id != null) {
          final account = accountById(id);
          await _recordActivity(
            'Drive opened',
            account?.email ?? id,
            accountEmail: account?.email,
          );
        }
      }, message: id == null ? 'Calculating all Drives…' : 'Opening Drive…');

  Future<void> refresh() => _guard(() async {
        await _refreshQuotas();
        indexReady = false;
        await _loadFiles();
        await _buildGlobalIndex();
      });

  Future<void> _refreshQuotas() async {
    final refreshed = await Future.wait(accounts.map(api.refreshQuota));
    for (final account in refreshed) {
      final index = accounts.indexWhere((item) => item.id == account.id);
      if (index >= 0) accounts[index] = account;
    }
  }

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
        _rememberLocation();
        selectedAccountId = item.accountId;
        final path = paths.putIfAbsent(
          item.accountId,
          () => <FolderCrumb>[const FolderCrumb('root', 'My Drive')],
        );
        path.add(FolderCrumb(item.id, item.name));
        await _loadFiles();
        await _recordActivity(
          'Folder opened',
          item.name,
          accountEmail: item.accountEmail,
        );
      });

  Future<void> openCrumb(int index) => _guard(() async {
        if (selectedAccountId == null) return;
        if (index == currentPath.length - 1) return;
        _rememberLocation();
        paths[selectedAccountId!] = currentPath.take(index + 1).toList();
        await _loadFiles();
      });

  Future<void> goUp() => _guard(() async {
        if (selectedAccountId == null || currentPath.length <= 1) return;
        _rememberLocation();
        paths[selectedAccountId!] =
            currentPath.take(currentPath.length - 1).toList();
        await _loadFiles();
      });

  Future<void> goBack() => _guard(() async {
        if (_navigationHistory.isEmpty) return;
        final previous = _navigationHistory.removeLast();
        selectedAccountId = previous.accountId;
        if (previous.accountId != null) {
          paths[previous.accountId!] = List.of(previous.path);
        }
        await _loadFiles();
      }, message: 'Going back…');

  void _rememberLocation() {
    _navigationHistory.add(
      _NavigationState(selectedAccountId, List.of(currentPath)),
    );
    if (_navigationHistory.length > 50) _navigationHistory.removeAt(0);
  }

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

  Future<void> setQuery(String value) async {
    query = value;
    notifyListeners();
    if (value.trim().isNotEmpty && !indexReady && !indexing) {
      await _guard(_buildGlobalIndex, message: 'Searching all Drives…');
    }
  }

  void setSort(String value) {
    sort = value;
    notifyListeners();
  }

  Future<void> setViewMode(FileViewMode value) => _guard(() async {
    viewMode = value;
    selectedKeys.clear();
    if ((value == FileViewMode.exactDuplicates ||
            value == FileViewMode.nameConflicts) &&
        !indexReady) {
      await _buildGlobalIndex();
    }
  });

  Future<void> _buildGlobalIndex() async {
    indexing = true;
    notifyListeners();
    try {
      final groups = await Future.wait(accounts.map(api.listAllFiles));
      folderSizes.clear();
      for (final group in groups) {
        _calculateFolderSizes(group);
      }
      indexedFiles
        ..clear()
        ..addAll(groups.expand(_withLocations));
      indexReady = true;
    } finally {
      indexing = false;
      notifyListeners();
    }
  }

  void _calculateFolderSizes(List<DriveItem> accountItems) {
    final children = <String, List<DriveItem>>{};
    for (final item in accountItems) {
      for (final parentId in item.parents) {
        children.putIfAbsent(parentId, () => []).add(item);
      }
    }
    final cache = <String, int>{};
    int totalFor(String folderId, Set<String> visiting) {
      final cached = cache[folderId];
      if (cached != null) return cached;
      if (!visiting.add(folderId)) return 0;
      var total = 0;
      for (final item in children[folderId] ?? const <DriveItem>[]) {
        total += item.isFolder
            ? totalFor(item.id, visiting)
            : (item.size ?? 0);
      }
      visiting.remove(folderId);
      cache[folderId] = total;
      return total;
    }
    for (final folder in accountItems.where((item) => item.isFolder)) {
      folderSizes[keyOf(folder)] = totalFor(folder.id, <String>{});
    }
  }

  Iterable<DriveItem> _withLocations(List<DriveItem> accountItems) {
    final byId = {for (final item in accountItems) item.id: item};
    return accountItems.map((item) {
      final names = <String>[];
      final seen = <String>{};
      var parentId = item.parents.isEmpty ? null : item.parents.first;
      while (parentId != null && seen.add(parentId)) {
        final parent = byId[parentId];
        if (parent == null) break;
        names.insert(0, parent.name);
        parentId = parent.parents.isEmpty ? null : parent.parents.first;
      }
      return item.copyWithLocation(
        ['My Drive', ...names].join(' / '),
      );
    });
  }

  void setClipboard(ClipboardMode mode) {
    if (selectedItems.isEmpty) return;
    clipboard = DriveClipboard(mode, List.of(selectedItems));
    notifyListeners();
  }

  void setClipboardItem(ClipboardMode mode, DriveItem item) {
    clipboard = DriveClipboard(mode, [item]);
    selectedKeys
      ..clear()
      ..add(keyOf(item));
    notifyListeners();
  }

  void selectOnly(DriveItem item) {
    selectedKeys
      ..clear()
      ..add(keyOf(item));
    notifyListeners();
  }

  Future<void> moveItemToDriveRoot(DriveItem item, String accountId) async {
    setClipboardItem(ClipboardMode.move, item);
    selectedAccountId = accountId;
    paths[accountId] = <FolderCrumb>[const FolderCrumb('root', 'My Drive')];
    await paste();
  }

  Future<void> pasteIntoFolder(DriveItem folder) async {
    if (!folder.isFolder || clipboard == null) return;
    selectedAccountId = folder.accountId;
    paths[folder.accountId] = <FolderCrumb>[
      const FolderCrumb('root', 'My Drive'),
      FolderCrumb(folder.id, folder.name),
    ];
    await paste();
  }

  Future<void> disconnectAccount(String accountId) => _guard(() async {
    final email = accountById(accountId)?.email ?? accountId;
    await authorizer.forgetAccount(accountId);
    accounts.removeWhere((item) => item.id == accountId);
    files.removeWhere((item) => item.accountId == accountId);
    indexedFiles.removeWhere((item) => item.accountId == accountId);
    paths.remove(accountId);
    if (selectedAccountId == accountId) selectedAccountId = null;
    indexReady = false;
    selectedKeys.clear();
    await _loadFiles();
    await _recordActivity('Drive disconnected', email, accountEmail: email);
  }, message: 'Disconnecting Drive…');

  Future<void> createFolder(String name) => _guard(() async {
        final account = selectedAccount;
        if (account == null) throw const DriveApiException('Open one Drive first.');
        await api.createFolder(account, currentFolderId, name.trim());
        await _recordActivity(
          'Folder created',
          '${name.trim()} in ${currentPath.map((item) => item.name).join(' / ')}',
          accountEmail: account.email,
        );
        await _afterMutation();
      });

  Future<void> renameSelected(String name) => _guard(() async {
        if (selectedItems.length != 1) return;
        final item = selectedItems.single;
        await api.rename(accountById(item.accountId)!, item.id, name.trim());
        await _recordActivity(
          'Renamed',
          '${item.name} → ${name.trim()}',
          accountEmail: item.accountEmail,
        );
        await _afterMutation();
      });

  Future<void> trashSelected() => _guard(() async {
        for (final item in selectedItems) {
          await api.setTrashed(accountById(item.accountId)!, item.id, true);
          await _recordActivity(
            'Moved to Trash',
            item.name,
            accountEmail: item.accountEmail,
          );
        }
        await _afterMutation();
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
        await _recordActivity(
          'Uploaded',
          '$name (${bytes.length} bytes)',
          accountEmail: account.email,
        );
        await _afterMutation();
      });

  Future<Uint8List> download(DriveItem item) async {
    loading = true;
    operationMessage = 'Downloading ${item.name}…';
    error = null;
    notifyListeners();
    try {
      final bytes = await api.downloadBytes(accountById(item.accountId)!, item);
      await _recordActivity(
        'Downloaded',
        item.name,
        accountEmail: item.accountEmail,
      );
      return bytes;
    } finally {
      loading = false;
      operationMessage = 'Working…';
      notifyListeners();
    }
  }

  Future<void> paste() => _guard(() async {
        final clip = clipboard;
        final destination = selectedAccount;
        if (clip == null || destination == null) {
          throw const DriveApiException('Open the destination folder first.');
        }
        for (final item in clip.items) {
          final source = accountById(item.accountId)!;
          if (item.isFolder) {
            if (source.id == destination.id && clip.mode == ClipboardMode.move) {
              await api.move(source, item, currentFolderId);
            } else {
              final sourceStats = await _treeStats(source, item.id);
              final copiedFolderId = await _copyFolderTree(
                source,
                destination,
                item,
                currentFolderId,
              );
              final destinationStats =
                  await _treeStats(destination, copiedFolderId);
              final complete = sourceStats.files == destinationStats.files &&
                  sourceStats.folders == destinationStats.folders &&
                  (source.id != destination.id ||
                      sourceStats.bytes == destinationStats.bytes);
              if (!complete) {
                throw const DriveApiException(
                  'Transfer verification failed. The source was kept unchanged.',
                );
              }
              if (clip.mode == ClipboardMode.move) {
                await api.setTrashed(source, item.id, true);
              }
            }
          } else if (source.id == destination.id) {
            clip.mode == ClipboardMode.copy
                ? await api.copy(source, item, currentFolderId)
                : await api.move(source, item, currentFolderId);
          } else {
            final transfer = await api.downloadForTransfer(source, item);
            final uploadedId = await api.uploadBytes(
              destination,
              parentId: currentFolderId,
              name: transfer.name,
              bytes: transfer.bytes,
              mimeType: transfer.mimeType,
            );
            final verified = await api.verifyUploadedFile(
              destination,
              uploadedId,
              transfer.bytes.length,
            );
            if (!verified) {
              throw const DriveApiException(
                'Transfer verification failed. The source was kept unchanged.',
              );
            }
            if (clip.mode == ClipboardMode.move) {
              await api.setTrashed(source, item.id, true);
            }
          }
          await _recordActivity(
            clip.mode == ClipboardMode.copy ? 'Copied' : 'Moved',
            '${item.name} → ${destination.email} / ${currentPath.map((entry) => entry.name).join(' / ')}',
            accountEmail: destination.email,
          );
        }
        if (clip.mode == ClipboardMode.move) clipboard = null;
        await _afterMutation();
      });

  Future<String> _copyFolderTree(
    DriveAccount source,
    DriveAccount destination,
    DriveItem folder,
    String destinationParentId,
  ) async {
    final newFolderId = await api.createFolder(
      destination,
      destinationParentId,
      folder.name,
    );
    final children = await api.listFolder(source, folder.id);
    for (final child in children) {
      if (child.isFolder) {
        await _copyFolderTree(source, destination, child, newFolderId);
      } else if (source.id == destination.id) {
        await api.copy(source, child, newFolderId);
      } else {
        final transfer = await api.downloadForTransfer(source, child);
        await api.uploadBytes(
          destination,
          parentId: newFolderId,
          name: transfer.name,
          bytes: transfer.bytes,
          mimeType: transfer.mimeType,
        );
      }
    }
    return newFolderId;
  }

  Future<_TreeStats> _treeStats(
    DriveAccount account,
    String folderId,
  ) async {
    var stats = const _TreeStats(folders: 1, files: 0, bytes: 0);
    final children = await api.listFolder(account, folderId);
    for (final child in children) {
      if (child.isFolder) {
        stats += await _treeStats(account, child.id);
      } else {
        stats += _TreeStats(
          folders: 0,
          files: 1,
          bytes: child.size ?? 0,
        );
      }
    }
    return stats;
  }

  Future<void> _afterMutation() async {
    indexReady = false;
    await _loadFiles();
    await _buildGlobalIndex();
  }

  Future<void> clearActivityLog() async {
    activityLog.clear();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('farooqdrive.activityLog');
    notifyListeners();
  }

  Future<void> recordFileOpened(DriveItem item) => _recordActivity(
        'File opened',
        item.name,
        accountEmail: item.accountEmail,
      );

  Future<void> _recordActivity(
    String action,
    String details, {
    String? accountEmail,
  }) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    activityLog
      ..removeWhere((entry) => entry.timestamp.isBefore(cutoff))
      ..insert(
        0,
        ActivityEntry(
          action: action,
          details: details,
          accountEmail: accountEmail,
          timestamp: DateTime.now(),
        ),
      );
    if (activityLog.length > 400) {
      activityLog.removeRange(400, activityLog.length);
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'farooqdrive.activityLog',
      activityLog.map((entry) => entry.toJson()).toList(),
    );
    notifyListeners();
  }

  Future<void> _guard(
    Future<void> Function() action, {
    String message = 'Working…',
  }) async {
    loading = true;
    operationMessage = message;
    error = null;
    notifyListeners();
    try {
      await action();
    } on DriveApiException catch (exception) {
      error = exception.message;
      await _recordActivity('Failed', '$message: ${exception.message}');
    } catch (exception) {
      error = exception.toString();
      await _recordActivity('Failed', '$message: $exception');
    } finally {
      loading = false;
      operationMessage = 'Working…';
      notifyListeners();
    }
  }
}

class _TreeStats {
  const _TreeStats({
    required this.folders,
    required this.files,
    required this.bytes,
  });
  final int folders;
  final int files;
  final int bytes;

  _TreeStats operator +(_TreeStats other) => _TreeStats(
        folders: folders + other.folders,
        files: files + other.files,
        bytes: bytes + other.bytes,
      );
}

class _NavigationState {
  const _NavigationState(this.accountId, this.path);
  final String? accountId;
  final List<FolderCrumb> path;
}

class ActivityEntry {
  const ActivityEntry({
    required this.action,
    required this.details,
    required this.timestamp,
    this.accountEmail,
  });

  final String action;
  final String details;
  final DateTime timestamp;
  final String? accountEmail;

  static ActivityEntry? tryFromJson(String value) {
    try {
      final data = jsonDecode(value) as Map<String, dynamic>;
      return ActivityEntry(
        action: data['action'] as String? ?? 'Activity',
        details: data['details'] as String? ?? '',
        timestamp: DateTime.tryParse('${data['timestamp']}') ?? DateTime.now(),
        accountEmail: data['accountEmail'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  String toJson() => jsonEncode({
        'action': action,
        'details': details,
        'timestamp': timestamp.toIso8601String(),
        if (accountEmail != null) 'accountEmail': accountEmail,
      });
}
