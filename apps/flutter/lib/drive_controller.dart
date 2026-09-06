import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'google_auth.dart';
import 'cloud_drive_api.dart';
import 'google_drive_api.dart';
import 'models.dart';
import 'microsoft_auth.dart';
import 'onedrive_api.dart';
import 'verified_transfer.dart';
import 'transfer_spool.dart';

class DriveController extends ChangeNotifier {
  DriveController({CloudDriveApi? api, GoogleAccountAuthorizer? authorizer,
    MicrosoftAccountAuthorizer? microsoftAuthorizer,
    Map<CloudProviderType, CloudDriveApi> providers = const {},
  })
      : api = api ?? GoogleDriveApi(),
        _providers = Map.of(providers),
        microsoftAuthorizer = microsoftAuthorizer ?? MicrosoftAccountAuthorizer(),
        authorizer = authorizer ?? GoogleAccountAuthorizer() {
    if (MicrosoftAccountAuthorizer.supported) {
      _providers.putIfAbsent(CloudProviderType.onedrive,
        () => OneDriveApi(tokenResolver: this.microsoftAuthorizer.accessToken));
    }
  }

  final MicrosoftAccountAuthorizer microsoftAuthorizer;
  String microsoftClientId = '';
  bool get supportsMicrosoft => MicrosoftAccountAuthorizer.supported;
  bool get hasMicrosoftClientId => MicrosoftAccountAuthorizer.buildClientId.isNotEmpty || microsoftClientId.isNotEmpty;
  bool get hasOfficialMicrosoftClientId => MicrosoftAccountAuthorizer.buildClientId.isNotEmpty;

  final CloudDriveApi api;
  final Map<CloudProviderType, CloudDriveApi> _providers;

  CloudDriveApi apiFor(DriveAccount account) {
    final provider = _providers[account.provider] ??
        (account.provider == CloudProviderType.google ? api : null);
    if (provider == null || provider.providerType != account.provider) {
      throw const DriveApiException('This cloud provider is not configured.');
    }
    return provider;
  }
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
  String desktopClientSecret = '';
  String query = '';
  String sort = 'name';
  bool sortAscending = true;
  int _indexGeneration = 0;
  bool _disposed = false;
  String scanStatus = '';
  bool indexStale = false;
  DateTime? indexScannedAt;
  Future<void> _indexSave = Future<void>.value();

  Future<void> rescan() => _buildGlobalIndex();

  Future<void> _saveIndex() {
    final snapshot = <String, dynamic>{
      'date': indexScannedAt?.toIso8601String(), 'stale': indexStale,
      'exact': _exactKeys.toList(), 'conflicts': _conflictKeys.toList(),
      'sizes': Map<String, int>.of(folderSizes),
      'files': indexedFiles.map((i) => <String, dynamic>{
        'id': i.id, 'name': i.name, 'mimeType': i.mimeType, 'isFolder': i.isFolder,
        'accountId': i.accountId, 'accountEmail': i.accountEmail, 'size': i.size,
        'modifiedTime': i.modifiedTime?.toIso8601String(), 'parents': i.parents,
        'canDownload': i.canDownload, 'ownedByMe': i.ownedByMe, 'location': i.location,
      }).toList(),
    };
    _indexSave = _indexSave.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('farooqdrive.scanIndex.v1', await compute(jsonEncode, snapshot));
    }).catchError((Object _) {
      if (!_disposed) { scanStatus = 'Index available this session; could not save it on this device.'; notifyListeners(); }
    });
    return _indexSave;
  }

  Future<void> restoreSavedIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSort = prefs.getString('farooqdrive.sort');
      if (['name','account','size','modified','type'].contains(savedSort)) sort = savedSort!;
      sortAscending = prefs.getBool('farooqdrive.sortAscending') ?? true;
      final raw = prefs.getString('farooqdrive.scanIndex.v1');
      if (raw == null) return;
      final data = (await compute(jsonDecode, raw)) as Map<String, dynamic>;
      final ids = accounts.map((a) => a.id).toSet();
      final restored = (data['files'] as List).cast<Map<String, dynamic>>().where((d) => ids.contains(d['accountId'])).map((d) => DriveItem(
        id: d['id'] as String, name: d['name'] as String, mimeType: d['mimeType'] as String,
        isFolder: d['isFolder'] as bool, accountId: d['accountId'] as String,
        accountEmail: d['accountEmail'] as String, size: d['size'] as int?,
        modifiedTime: DateTime.tryParse(d['modifiedTime'] as String? ?? ''),
        parents: (d['parents'] as List).cast<String>(), canDownload: d['canDownload'] as bool,
        ownedByMe: d['ownedByMe'] as bool, location: d['location'] as String)).toList();
      if (_disposed) return;
      indexedFiles..clear()..addAll(restored);
      final keys = restored.map(keyOf).toSet();
      _exactKeys..clear()..addAll((data['exact'] as List).cast<String>().where(keys.contains));
      _conflictKeys..clear()..addAll((data['conflicts'] as List).cast<String>().where(keys.contains));
      folderSizes..clear()..addAll(Map<String,int>.from(data['sizes'] as Map)..removeWhere((k,v) => !keys.contains(k)));
      indexScannedAt = DateTime.tryParse(data['date'] as String? ?? '');
      indexReady = indexScannedAt != null;
      indexStale = true;
      scanStatus = 'Saved index restored. Rescan to check for cloud changes.';
      notifyListeners();
    } catch (_) { /* Invalid cache does not prevent sign-in or browsing. */ }
  }

  final Set<String> _exactKeys = {};
  final Set<String> _conflictKeys = {};
  @override
  void dispose() { _disposed = true; _indexGeneration++; super.dispose(); }
  String layout = 'details';
  void setLayout(String value) { layout = value; notifyListeners(); }
  FileViewMode viewMode = FileViewMode.all;
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
  bool get hasRequiredCredentials => hasClientId &&
      (!GoogleAccountAuthorizer.requiresClientSecret ||
          desktopClientSecret.trim().isNotEmpty);
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

  List<DriveItem> matchingItemsFor(FileViewMode mode) {
    final normalized = query
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[*?]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    final searchTerms = normalized.split(' ').where((item) => item.isNotEmpty);
    final duplicateView = mode == FileViewMode.exactDuplicates ||
        mode == FileViewMode.nameConflicts;
    final useGlobalIndex = duplicateView ||
        (normalized.isNotEmpty && indexReady);
    final source = useGlobalIndex && indexReady ? indexedFiles :
        (duplicateView ? <DriveItem>[] : files);
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
      return switch (mode) {
        FileViewMode.all => true,
        FileViewMode.files => !item.isFolder,
        FileViewMode.folders => item.isFolder,
        FileViewMode.exactDuplicates => isExactDuplicate(item),
        FileViewMode.nameConflicts => isNameConflict(item),
      };
    }).toList();
    result.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      final comparison = switch (sort) {
        'size' => (sizeOf(a) ?? -1).compareTo(sizeOf(b) ?? -1),
        'modified' => (a.modifiedTime ?? DateTime(0)).compareTo(b.modifiedTime ?? DateTime(0)),
        'account' => a.accountEmail.toLowerCase().compareTo(b.accountEmail.toLowerCase()),
        'type' => a.mimeType.compareTo(b.mimeType),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      final stable = comparison == 0 ? keyOf(a).compareTo(keyOf(b)) : comparison;
      return sortAscending ? stable : -stable;
    });
    return result;
  }

  List<DriveItem> get visibleFiles => matchingItemsFor(viewMode);

  bool isExactDuplicate(DriveItem item) => _exactKeys.contains(keyOf(item));
  bool isNameConflict(DriveItem item) => _conflictKeys.contains(keyOf(item));

  int get exactDuplicateCount =>
      matchingItemsFor(FileViewMode.exactDuplicates).length;
  int get nameConflictCount =>
      matchingItemsFor(FileViewMode.nameConflicts).length;
  int get fileCount => matchingItemsFor(FileViewMode.files).length;
  int get folderCount => matchingItemsFor(FileViewMode.folders).length;
  int get allItemCount => matchingItemsFor(FileViewMode.all).length;

  Future<void> initialize() async {
    loading = true;
    operationMessage = 'Restoring cloud accounts…';
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      microsoftClientId = preferences.getString('farooqdrive.microsoft.clientId') ?? '';
      webClientId = preferences.getString('farooqdrive.googleClientId') ??
          preferences.getString('farooqdrive.webClientId') ??
          '';
      try { desktopClientSecret = await authorizer.loadClientSecret(); }
      catch (_) { error = 'Saved Google settings could not be loaded.'; }
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      activityLog
        ..clear()
        ..addAll(
          (preferences.getStringList('farooqdrive.activityLog') ?? const [])
              .map(ActivityEntry.tryFromJson)
              .whereType<ActivityEntry>()
              .where((entry) => entry.timestamp.isAfter(cutoff)),
        );
      final restored = <DriveAccount>[];
      try {
        restored.addAll(await authorizer.restoreAccounts(webClientId, desktopClientSecret));
      } catch (_) { error = 'Some Google accounts need sign-in again.'; }
      try {
        restored.addAll(await microsoftAuthorizer.restoreAccounts());
        if (microsoftAuthorizer.restoreWarnings.isNotEmpty) {
          error = [if (error != null) error!, ...microsoftAuthorizer.restoreWarnings].join(' ');
        }
      } catch (_) { error = '${error ?? ''} Microsoft accounts could not be restored. Sign in again.'.trim(); }
      accounts
        ..clear()
        ..addAll(restored);
      for (final account in accounts) {
        paths[account.id] = <FolderCrumb>[
          FolderCrumb(apiFor(account).rootFolderId, apiFor(account).rootFolderLabel),
        ];
      }
      await restoreSavedIndex();
      if (accounts.isNotEmpty) {
        selectedAccountId = accounts.first.id;
        await _refreshQuotas();
        await _loadFiles();
      }
    } catch (exception) {
      error = 'Saved accounts could not be restored: $exception';
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

  Future<void> saveMicrosoftClientId(String value) async {
    final id = value.trim();
    if (!RegExp(r'^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$').hasMatch(id)) {
      error = 'Enter a valid Microsoft Application (client) ID.';
      notifyListeners();
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('farooqdrive.microsoft.clientId', id);
    microsoftClientId = id;
    error = null;
    notifyListeners();
  }

  Future<void> addMicrosoftAccount() => _guard(() async {
    final added = await microsoftAuthorizer.addAccount(microsoftClientId);
    if (added == null) return;
    final index = accounts.indexWhere((account) => account.id == added.id);
    if (index < 0) { accounts.add(added); } else { accounts[index] = added; }
    paths[added.id] = [FolderCrumb(apiFor(added).rootFolderId, apiFor(added).rootFolderLabel)];
    selectedAccountId = added.id;
    _invalidateIndex();
    try {
      final updated = await apiFor(added).refreshQuota(added);
      accounts[accounts.indexWhere((account) => account.id == added.id)] = updated;
    } catch (_) { error = 'OneDrive quota is unavailable. Check that OneDrive is provisioned and permitted for this account.'; }
    await _loadFiles();
    await _recordActivity('Microsoft OneDrive connected', added.email, accountEmail: added.email);
  }, message: 'Signing in to Microsoft…');

  Future<void> saveClientSecret(String value) async {
    final secret = value.trim();
    if (secret.isEmpty) {
      error = 'Enter your Google Desktop Client Secret.';
      notifyListeners();
      return;
    }
    await authorizer.saveClientSecret(secret);
    desktopClientSecret = secret;
    error = null;
    notifyListeners();
  }

  Future<void> addAccount() => _guard(() async {
        if ((!hasClientId && GoogleAccountAuthorizer.buildClientId.isEmpty) ||
            (GoogleAccountAuthorizer.requiresClientSecret &&
                desktopClientSecret.isEmpty)) {
          throw const DriveApiException(
            GoogleAccountAuthorizer.missingClientIdMessage,
          );
        }
        final added = await authorizer.addAccount(
          webClientId,
          desktopClientSecret,
        );
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
        _invalidateIndex();
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
        // Refresh is a read, not a mutation: do not cancel an active scan.
        treeRevision++;
        if (indexReady) {
          indexStale = true;
          if (!indexing) scanStatus = 'Saved scan results retained — press Rescan to update.';
          _saveIndex();
        }
        await _loadFiles();
      });

  Future<void> _refreshQuotas() async {
    final refreshed = await Future.wait(accounts.map((account) async {
      try { return await apiFor(account).refreshQuota(account); }
      catch (_) { error = '${error ?? ''} Quota unavailable for ${account.email}.'.trim(); return account; }
    }));
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
      return apiFor(account).listFolder(account, folder).catchError((Object _) {
        error = '${error ?? ''} Could not open ${account.email}. Check sign-in, OneDrive provisioning or organization access.'.trim();
        return <DriveItem>[];
      });
    }));
    files.clear();
    for (var index = 0; index < groups.length; index++) {
      final account = targets[index];
      final location = allDrives
          ? apiFor(account).rootFolderLabel
          : (paths[account.id] ?? const [FolderCrumb('root', 'My Drive')])
              .map((crumb) => crumb.name)
              .join(' / ');
      files.addAll(groups[index].map((item) => item.copyWithLocation(location)));
    }
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
      await _buildGlobalIndex();
    }
  }

  void setSort(String value) {
    sortAscending = sort == value ? !sortAscending : true;
    sort = value;
    _saveSort();
    notifyListeners();
  }

  Future<void> _saveSort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('farooqdrive.sort', sort);
      await prefs.setBool('farooqdrive.sortAscending', sortAscending);
    } catch (_) { /* Sorting remains available this session. */ }
  }

  Future<void> setViewMode(FileViewMode value) async {
    final scan = value == FileViewMode.exactDuplicates || value == FileViewMode.nameConflicts;
    viewMode = value;
    selectedKeys.clear();
    notifyListeners();
    if (scan && !indexReady) await _buildGlobalIndex();
  }

  Future<void> _buildGlobalIndex() async {
    if (indexing || _disposed) return;
    final generation = _indexGeneration;
    final targets = List<DriveAccount>.of(accounts);
    indexing = true;
    if (error?.startsWith('Scan failed') ?? false) error = null;
    scanStatus = 'Scan running in background — you can continue working.';
    String stage = 'Starting scan';
    notifyListeners();
    try {
      final collected = <DriveItem>[];
      for (final account in targets) {
        stage = '${account.provider == CloudProviderType.onedrive ? "OneDrive" : "Google Drive"} — ${account.email}';
        scanStatus = 'Scanning $stage — waiting for the first page…';
        notifyListeners();
        final group = await apiFor(account).listAllFiles(account, onProgress: (count) {
          if (_disposed || generation != _indexGeneration) throw const DriveApiException('Scan cancelled because files changed.');
          scanStatus = 'Scanning $stage — $count items read. You can continue working.';
          notifyListeners();
        });
        if (_disposed || generation != _indexGeneration) return;
        collected.addAll(_withLocations(group));
        await Future<void>.delayed(Duration.zero);
      }
      stage = 'Matching names and sizes';
      scanStatus = '$stage — ${collected.length} items read.';
      notifyListeners();
      final names = <String, List<DriveItem>>{};
      for (var i = 0; i < collected.length; i++) {
        final item = collected[i];
        if (!item.isFolder) names.putIfAbsent(item.name.trim().toLowerCase(), () => []).add(item);
        if (i % 250 == 0) await Future<void>.delayed(Duration.zero);
      }
      final exact = <String>{}, conflicts = <String>{};
      var matchedGroups = 0;
      for (final group in names.values) {
        final sizes = <int?, List<DriveItem>>{};
        for (final item in group) { sizes.putIfAbsent(item.size, () => []).add(item); }
        for (final entry in sizes.entries) {
          if (entry.key != null && entry.value.length > 1) exact.addAll(entry.value.map(keyOf));
        }
        if (group.length > 1 && (sizes.length > 1 || sizes.containsKey(null))) conflicts.addAll(group.map(keyOf));
        if (++matchedGroups % 250 == 0) await Future<void>.delayed(Duration.zero);
      }
      if (_disposed || generation != _indexGeneration) return;
      folderSizes.clear();
      for (final account in targets) { _calculateFolderSizes(collected.where((item) => item.accountId == account.id).toList()); }
      indexedFiles..clear()..addAll(collected);
      _exactKeys..clear()..addAll(exact);
      _conflictKeys..clear()..addAll(conflicts);
      indexReady = true;
      indexStale = false;
      indexScannedAt = DateTime.now();
      scanStatus = 'Scan complete: ${collected.length} items; ${exact.length} matching-name/size files; ${conflicts.length} same-name conflicts.';
      await _saveIndex();
    } catch (exception) {
      if (!_disposed) {
        final reason = exception is TimeoutException ? 'No response within 60 seconds. Check the connection and retry.'
            : exception is DriveApiException ? (exception.statusCode == 401
                ? 'Sign-in expired. Reconnect this account, then Rescan all.'
                : exception.statusCode == 403 ? 'Access denied. Check this account’s permissions.'
                : 'Provider scan error${exception.statusCode == null ? "" : " (${exception.statusCode})"}. ${exception.message.startsWith("OneDrive") || exception.message.startsWith("Google") ? exception.message : "Check account access and retry."}')
            : 'Could not process the scan. Previous saved results remain; contact support with this stage.';
        scanStatus = 'Scan failed at $stage. $reason Previous index retained.';
        error = scanStatus;
      }
    } finally {
      if (!_disposed) {
        if (generation != _indexGeneration) scanStatus = 'Files changed during scan. Run the scan again for current results.';
        indexing = false;
        notifyListeners();
      }
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
        [apiFor(accountById(item.accountId)!).rootFolderLabel, ...names].join(' / '),
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
    final provider = apiFor(accountById(accountId)!);
    paths[accountId] = <FolderCrumb>[FolderCrumb(provider.rootFolderId, provider.rootFolderLabel)];
    await paste();
  }

  Future<void> pasteIntoFolder(DriveItem folder) async {
    if (!folder.isFolder || clipboard == null) return;
    selectedAccountId = folder.accountId;
    paths[folder.accountId] = <FolderCrumb>[
      FolderCrumb(apiFor(accountById(folder.accountId)!).rootFolderId, apiFor(accountById(folder.accountId)!).rootFolderLabel),
      FolderCrumb(folder.id, folder.name),
    ];
    await paste();
  }

  Future<void> disconnectAccount(String accountId) => _guard(() async {
    final email = accountById(accountId)?.email ?? accountId;
    if (accountById(accountId)?.provider == CloudProviderType.onedrive) {
      await microsoftAuthorizer.forgetAccount(accountId);
    } else {
      await authorizer.forgetAccount(accountId);
    }
    accounts.removeWhere((item) => item.id == accountId);
    files.removeWhere((item) => item.accountId == accountId);
    indexedFiles.removeWhere((item) => item.accountId == accountId);
    paths.remove(accountId);
    if (selectedAccountId == accountId) selectedAccountId = null;
    final remainingKeys = indexedFiles.map(keyOf).toSet();
    _exactKeys.removeWhere((key) => !remainingKeys.contains(key));
    _conflictKeys.removeWhere((key) => !remainingKeys.contains(key));
    folderSizes.removeWhere((key, value) => !remainingKeys.contains(key));
    _invalidateIndex();
    await _saveIndex();
    selectedKeys.clear();
    await _loadFiles();
    await _recordActivity('Drive disconnected', email, accountEmail: email);
  }, message: 'Disconnecting Drive…');

  Future<void> createFolder(String name) => _guard(() async {
        final account = selectedAccount;
        if (account == null) throw const DriveApiException('Open one Drive first.');
        await apiFor(account).createFolder(account, currentFolderId, name.trim());
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
        final account = accountById(item.accountId)!;
        await apiFor(account).rename(account, item.id, name.trim());
        await _recordActivity(
          'Renamed',
          '${item.name} → ${name.trim()}',
          accountEmail: item.accountEmail,
        );
        await _afterMutation();
      });

  Future<void> trashSelected() => _guard(() async {
        for (final item in selectedItems) {
          final account = accountById(item.accountId)!;
          await apiFor(account).setTrashed(account, item.id, true);
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
        await apiFor(account).uploadBytes(
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

  Future<void> uploadFromStream(String name, Stream<List<int>> input, int size) => _guard(() async {
    final account = selectedAccount;
    if (account == null) throw const DriveApiException('Open the destination Drive first.');
    if (size > VerifiedTransfer.fileLimit) throw const DriveApiException(kIsWeb ? 'Web upload limit is 32 MiB per file.' : 'Windows upload limit is 1 GiB per file.');
    final parent = currentFolderId;
    final provider = apiFor(account);
    final spool = await TransferSpool.create();
    transferActive = true;
    _cancelTransfer = false;
    transferResult = '';
    try {
      operationMessage = 'Preparing $name in temporary storage…';
      notifyListeners();
      await spool.write(input, size, (_) => _checkTransferCancelled());
      final id = await provider.uploadTransfer(account, parent, name, 'application/octet-stream', spool.length, (start, end) {
        _checkTransferCancelled();
        operationMessage = 'Uploading $name: ${(start / 1048576).toStringAsFixed(1)} / ${(size / 1048576).toStringAsFixed(1)} MiB';
        notifyListeners();
        return spool.readRange(start, end);
      });
      final uploaded = await provider.snapshot(account, id);
      if (uploaded.item.size != spool.length) throw const DriveApiException('Uploaded size differs. Local original retained.');
      operationMessage = 'Verifying uploaded $name…';
      notifyListeners();
      final download = await provider.openTransfer(account, uploaded.item);
      var received = 0;
      final digest = await sha256.bind(download.stream.timeout(const Duration(seconds: 60)).map((bytes) {
        _checkTransferCancelled();
        received += bytes.length;
        if (received > size) throw const DriveApiException('Uploaded content size changed.');
        return bytes;
      })).first;
      if (received != size || digest.toString() != spool.digest ||
          (await provider.snapshot(account, id)).revision != uploaded.revision) {
        throw const DriveApiException('Upload content verification failed. Local original retained. Review the destination copy.');
      }
      transferResult = 'Uploaded and SHA-256 verified: ${uploaded.item.name} → ${account.email}. Local original retained.';
      await _recordActivity('Upload verified', transferResult, accountEmail: account.email);
    } on DriveApiException {
      transferResult = 'Upload interrupted. Local original retained. A partial or completed destination copy may remain; see Activity for the error.';
      rethrow;
    } catch (_) {
      throw const DriveApiException(kIsWeb ? 'Upload interrupted. Check browser memory, connection and provider access. Local original retained.' : 'Upload interrupted. Check temporary disk space and your connection. Local original retained.');
    } finally {
      transferActive = false;
      await spool.close();
      await _afterMutation();
    }
  }, message: 'Uploading local file…');

  Future<Uint8List> download(DriveItem item) async {
    loading = true;
    operationMessage = 'Downloading ${item.name}…';
    error = null;
    notifyListeners();
    try {
      final account = accountById(item.accountId)!;
      final Uint8List bytes;
      if (kIsWeb) {
        final spool = await TransferSpool.create();
        try {
          if ((item.size ?? 0) > VerifiedTransfer.fileLimit) throw const DriveApiException('Web downloads support up to 32 MiB per file.');
          final source = await apiFor(account).openTransfer(account, item);
          await spool.write(source.stream, source.length, (_) {});
          bytes = await spool.readRange(0, spool.length);
        } finally { await spool.close(); }
      } else {
        bytes = await apiFor(account).downloadBytes(account, item);
      }
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

  Future<bool> Function(List<VerifiedCopy> files, int retained)? confirmSourceCleanup;
  String transferResult = '';
  bool transferActive = false;
  bool _cancelTransfer = false;
  int treeRevision = 0;
  void cancelTransfer() { _cancelTransfer = true; }
  void _checkTransferCancelled() {
    if (_cancelTransfer) throw const DriveApiException('Transfer cancelled. Unconfirmed sources retained; any completed copies remain at the destination.');
  }

  Future<void> paste() async {
    if (loading) return;
    await _guard(() async {
      final clip = clipboard;
      final destination = selectedAccount;
      final parent = currentFolderId;
      if (clip == null || destination == null) throw const DriveApiException('Open the destination folder first.');
      _cancelTransfer = false;
      transferActive = true;
      transferResult = '';
      final transfer = VerifiedTransfer(apiFor, (message) {
        operationMessage = message;
        notifyListeners();
      }, _checkTransferCancelled);
      try {
        await transfer.run([
          for (final item in clip.items) (accountById(item.accountId) ?? (throw const DriveApiException('Source account disconnected.')), item),
        ], destination, parent);
        final eligible = transfer.copies.where((copy) => copy.source.trashTag != null).toList();
        final retained = transfer.copies.length - eligible.length + transfer.nativeCopies;
        var cleaned = 0;
        if (clip.mode == ClipboardMode.move && eligible.isNotEmpty) {
          _checkTransferCancelled();
          final accepted = await confirmSourceCleanup?.call(List.unmodifiable(eligible), retained) ?? false;
          if (accepted) {
            for (final copy in eligible) {
              operationMessage = 'Rechecking and recycling ${copy.source.item.name}…';
              notifyListeners();
              await transfer.cleanup(copy);
              cleaned++;
              await _recordActivity('Verified source recycled', '${copy.source.item.name} → ${destination.email}', accountEmail: copy.sourceAccount.email);
            }
          }
        }
        transferResult = '${transfer.copies.length} file(s) copied and SHA-256 verified. $cleaned source file(s) moved to Recycle Bin. Original folder containers remain. '
          '${transfer.nativeCopies > 0 ? "${transfer.nativeCopies} Google-native copy/copies preserved their format; not byte-verified, originals retained. " : ""}'
          '${clip.mode == ClipboardMode.move && retained > 0 ? "$retained source file(s) retained because conditional cleanup is unavailable." : ""}';
        await _recordActivity('Transfer complete', transferResult, accountEmail: destination.email);
        if (clip.mode == ClipboardMode.move) clipboard = null;
      } on DriveApiException {
        transferResult = '${transfer.copies.length} file(s) verified before interruption. Review Activity for any confirmed source cleanup; other sources remain. Partial destination copies may remain.';
        rethrow;
      } catch (_) {
        transferResult = '${transfer.copies.length} file(s) verified before interruption. Partial destination copies may remain. No further source cleanup was performed.';
        throw const DriveApiException('Transfer interrupted by a storage or connection error. Check disk space and sign-in, then retry. Existing destination copies are retained.');
      } finally {
        transferActive = false;
        await _afterMutation();
      }
    }, message: 'Preparing verified transfer…');
  }

  Future<void> navigateTree(String accountId, List<FolderCrumb> path) => _guard(() async {
    _rememberLocation();
    selectedAccountId = accountId;
    paths[accountId] = List.of(path);
    selectedKeys.clear();
    query = '';
    viewMode = FileViewMode.all;
    await _loadFiles();
  });

  Future<void> _afterMutation() async {
    _invalidateIndex();
    await _loadFiles();
  }

  void _invalidateIndex() {
    _indexGeneration++;
    treeRevision++;
    if (indexReady) {
      indexStale = true;
      scanStatus = 'Saved scan results retained — press Rescan to update.';
      _saveIndex();
    }
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
    if (loading) return;
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
