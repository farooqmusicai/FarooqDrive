import 'dart:typed_data';

import 'package:farooqdrive/drive_controller.dart';
import 'package:farooqdrive/google_drive_api.dart';
import 'package:farooqdrive/cloud_drive_api.dart';
import 'package:farooqdrive/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordingApi extends GoogleDriveApi {
  RecordingApi(this.type);
  final CloudProviderType type;
  int scans = 0;
  int downloads = 0;
  int uploads = 0;
  int verifications = 0;
  int trashes = 0;
  bool corrupt = false;
  bool changed = false;
  final List<DriveItem> items = [];
  @override
  Future<TransferSnapshot> snapshot(DriveAccount account, String id) async => TransferSnapshot(
    DriveItem(id: id, name: 'File', mimeType: 'application/octet-stream', isFolder: false,
      accountId: account.id, accountEmail: account.email, size: 3, parents: const ['root']),
    changed ? 'v2' : 'v1', trashTag: type == CloudProviderType.onedrive ? 'v1' : null);
  @override
  Future<TransferDownload> openTransfer(DriveAccount account, DriveItem item) async {
    downloads++;
    return TransferDownload(item.name, item.mimeType, Stream.value(corrupt ? [3, 2, 1] : [1, 2, 3]), 3);
  }
  @override
  Future<String> uploadTransfer(DriveAccount account, String parentId, String name,
      String mimeType, int length, Future<Uint8List> Function(int, int) readRange) async {
    expect(await readRange(0, length), [1, 2, 3]);
    uploads++;
    return 'uploaded';
  }
  @override
  Future<void> trashUnchanged(DriveAccount account, TransferSnapshot source) async { trashes++; }
  @override
  CloudProviderType get providerType => type;
  @override
  Future<List<DriveItem>> listFolder(DriveAccount account, String folderId) async => List.of(items);
  @override
  Future<List<DriveItem>> listAllFiles(DriveAccount account, {void Function(int count)? onProgress}) async {
    scans++;
    return List.of(items);
  }
  @override
  Future<DriveAccount> refreshQuota(DriveAccount account) async => account;
  @override
  Future<String> createFolder(DriveAccount account, String parentId, String name) async => 'new-folder';
  @override
  Future<TransferFile> downloadForTransfer(DriveAccount account, DriveItem item) async {
    downloads++;
    return TransferFile(item.name, item.mimeType, Uint8List.fromList([1, 2, 3]));
  }
  @override
  Future<String> uploadBytes(DriveAccount account, {
    required String parentId, required String name, required Uint8List bytes,
    String mimeType = 'application/octet-stream',
  }) async {
    uploads++;
    return 'uploaded';
  }
  @override
  Future<bool> verifyUploadedFile(DriveAccount account, String fileId, int expectedSize) async {
    verifications++;
    return fileId == 'uploaded' && expectedSize == 3;
  }
  @override
  Future<void> setTrashed(DriveAccount account, String id, bool trashed) async {
    trashes++;
  }
}

DriveAccount account(String id, CloudProviderType provider) => DriveAccount(
  id: id, email: '$id@example.invalid', name: id, accessToken: 'test', provider: provider,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('browse refresh and folder creation do not trigger full scans', () async {
    final api = RecordingApi(CloudProviderType.google);
    final controller = DriveController(api: api);
    addTearDown(controller.dispose);
    controller.accounts.add(account('g', CloudProviderType.google));
    await controller.selectAccount('g');
    await controller.refresh();
    await controller.createFolder('New');
    expect(controller.error, isNull);
    expect(api.scans, 0);
    await controller.setQuery('find');
    expect(api.scans, 1);
    await controller.refresh();
    expect(api.scans, 1);
    expect(controller.indexReady, isTrue);
    expect(controller.indexStale, isTrue);
    expect(controller.indexedFiles, isEmpty);
    await controller.setViewMode(FileViewMode.exactDuplicates);
    expect(api.scans, 1);
    await controller.rescan();
    expect(api.scans, 2);
  });

  test('mismatched Microsoft provider never falls back to Google', () {
    final controller = DriveController(providers: {
      CloudProviderType.onedrive: RecordingApi(CloudProviderType.google),
    });
    addTearDown(controller.dispose);
    expect(() => controller.apiFor(account('m', CloudProviderType.onedrive)),
      throwsA(isA<DriveApiException>()));
  });

  test('cross-provider copy uses source download and destination verification', () async {
    final google = RecordingApi(CloudProviderType.google);
    final microsoft = RecordingApi(CloudProviderType.onedrive);
    final controller = DriveController(api: google, providers: {
      CloudProviderType.onedrive: microsoft,
    });
    addTearDown(controller.dispose);
    controller.accounts.addAll([
      account('g', CloudProviderType.google), account('m', CloudProviderType.onedrive),
    ]);
    controller.selectedAccountId = 'm';
    controller.clipboard = const DriveClipboard(ClipboardMode.copy, [
      DriveItem(id: 'file', name: 'File', mimeType: 'application/octet-stream',
        isFolder: false, accountId: 'g', accountEmail: 'g@example.invalid'),
    ]);
    await controller.paste();
    expect(controller.error, isNull);
    expect(google.downloads, 1);
    expect(google.uploads, 0);
    expect(google.verifications, 0);
    expect(microsoft.downloads, 1);
    expect(microsoft.uploads, 1);
    expect(microsoft.verifications, 0);
    expect(google.trashes + microsoft.trashes, 0);
    expect(google.scans + microsoft.scans, 0);
    controller.clipboard = DriveClipboard(ClipboardMode.move, controller.clipboard!.items);
    await controller.paste();
    expect(controller.error, isNull);
    expect(controller.transferResult, contains('conditional cleanup is unavailable'));
    expect(google.downloads, 2);
    expect(microsoft.uploads, 2);
    expect(google.trashes + microsoft.trashes, 0);
  });

  for (final scenario in ['yes', 'no', 'changed', 'corrupt', 'dismissed']) {
    test('safe move: $scenario', () async {
      final source = RecordingApi(CloudProviderType.onedrive);
      final target = RecordingApi(CloudProviderType.google)..corrupt = scenario == 'corrupt';
      final controller = DriveController(api: target, providers: {CloudProviderType.onedrive: source});
      addTearDown(controller.dispose);
      controller.accounts.addAll([account('m', CloudProviderType.onedrive), account('g', CloudProviderType.google)]);
      controller.selectedAccountId = 'g';
      controller.clipboard = const DriveClipboard(ClipboardMode.move, [DriveItem(
        id: 'file', name: 'File', mimeType: 'application/octet-stream', isFolder: false,
        accountId: 'm', accountEmail: 'm@example.invalid', size: 3)]);
      var prompts = 0;
      if (scenario != 'dismissed') { controller.confirmSourceCleanup = (files, retained) async {
        prompts++;
        expect(source.trashes, 0);
        expect(target.downloads, 1);
        if (scenario == 'changed') source.changed = true;
        return scenario != 'no';
      }; }
      await controller.paste();
      expect(source.trashes, scenario == 'yes' ? 1 : 0);
      expect(prompts, ['corrupt','dismissed'].contains(scenario) ? 0 : 1);
      expect(controller.error, ['changed','corrupt'].contains(scenario) ? isNotNull : isNull);
    });
  }

  for (final corrupt in [false, true]) {
    test('local streamed OneDrive upload verifies contents, corrupt=$corrupt', () async {
      final api = RecordingApi(CloudProviderType.onedrive)..corrupt = corrupt;
      final controller = DriveController(providers: {CloudProviderType.onedrive: api});
      addTearDown(controller.dispose);
      controller.accounts.add(account('m', CloudProviderType.onedrive));
      controller.selectedAccountId = 'm';
      await controller.uploadFromStream('file.bin', Stream.value([1,2,3]), 3);
      expect(api.uploads, 1);
      expect(api.downloads, 1);
      expect(api.trashes, 0);
      expect(controller.error, corrupt ? contains('verification failed') : isNull);
    });
  }
}
