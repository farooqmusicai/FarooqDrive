import 'dart:async';
import 'package:farooqdrive/drive_controller.dart';
import 'package:farooqdrive/cloud_drive_api.dart';
import 'package:farooqdrive/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'controller_provider_test.dart' show RecordingApi, account;

class SlowApi extends RecordingApi {
  SlowApi() : super(CloudProviderType.google);
  final done = Completer<List<DriveItem>>();
  @override
  Future<List<DriveItem>> listAllFiles(DriveAccount account, {void Function(int count)? onProgress}) => done.future;
}
DriveItem item(String id, String name, int size, String email, int year) => DriveItem(
  id: id, name: name, size: size, accountId: 'g', accountEmail: email,
  mimeType: 'text/plain', isFolder: false, modifiedTime: DateTime(year));
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('columns toggle ascending and descending with stable ties', () {
    final c = DriveController();
    addTearDown(c.dispose);
    c.files.addAll([item('1','Alpha',1,'a@x',2020), item('2','Zulu',2,'z@x',2021)]);
    for (final column in ['name','account','size','modified']) {
      if (c.sort != column) c.setSort(column);
      expect(c.visibleFiles.first.id, '1');
      c.setSort(column);
      expect(c.visibleFiles.first.id, '2');
      c.setSort(column);
      expect(c.visibleFiles.first.id, '1');
    }
  });
  test('scan permits navigation and publishes results without changing view', () async {
    final api = SlowApi();
    final c = DriveController(api: api);
    addTearDown(c.dispose);
    c.accounts.add(account('g',CloudProviderType.google));
    final scan = c.setViewMode(FileViewMode.exactDuplicates);
    expect(c.indexing, isTrue);
    expect(c.viewMode,FileViewMode.exactDuplicates);
    expect(c.loading, isFalse);
    await c.selectAccount('g');
    await c.refresh(); // A read-only refresh must not invalidate the active scan.
    await c.setViewMode(FileViewMode.files);
    api.done.complete([item('1','A',3,'a@x',2020),item('2','A',3,'a@x',2020),item('3','A',4,'a@x',2020)]);
    await scan;
    expect(c.viewMode, FileViewMode.files);
    expect(c.indexReady,isTrue);
    expect(c.exactDuplicateCount,2);
    expect(c.nameConflictCount,3);
  });
  test('mutation during scan discards stale snapshot', () async {
    final api = SlowApi();
    final c = DriveController(api: api);
    addTearDown(c.dispose);
    c.accounts.add(account('g',CloudProviderType.google));
    await c.selectAccount('g');
    final scan = c.setViewMode(FileViewMode.nameConflicts);
    await c.createFolder('New');
    api.done.complete([item('1','A',3,'a@x',2020)]);
    await scan;
    expect(c.indexReady,isFalse);
    expect(c.indexedFiles,isEmpty);
    expect(c.indexing,isFalse);
  });
  test('saved index survives refresh, tab changes and controller restart', () async {
    final api = RecordingApi(CloudProviderType.google);
    api.items.addAll([item('1','A',3,'a@x',2020),item('2','A',3,'a@x',2020)]);
    final c = DriveController(api: api);
    addTearDown(c.dispose);
    c.accounts.add(account('g',CloudProviderType.google));
    await c.selectAccount('g');
    await c.rescan();
    await c.refresh();
    await c.setViewMode(FileViewMode.exactDuplicates);
    expect(c.exactDuplicateCount,2);
    expect(api.scans,1);
    final restored = DriveController(api: api);
    addTearDown(restored.dispose);
    restored.accounts.add(account('g',CloudProviderType.google));
    await restored.restoreSavedIndex();
    expect(restored.indexReady,isTrue);
    expect(restored.exactDuplicateCount,2);
    expect(restored.indexStale,isTrue);
    api.items.clear();
    await restored.rescan();
    expect(restored.exactDuplicateCount,0);
    expect(restored.indexStale,isFalse);
  });

  test('scan error names failing account and keeps the saved index', () async {
    final api=SlowApi();
    final c=DriveController(api:api);
    addTearDown(c.dispose);
    c.accounts.add(account('g',CloudProviderType.google));
    c.indexReady=true;
    c.indexedFiles.add(item('old','Retained',3,'a@x',2020));
    final scan=c.rescan();
    api.done.completeError(const DriveApiException('Denied',statusCode:403));
    await scan;
    expect(c.indexedFiles.single.id,'old');
    expect(c.indexReady,isTrue);
    expect(c.scanStatus,contains('g@example.invalid'));
    expect(c.scanStatus,contains('Access denied'));
    expect(c.indexing,isFalse);
  });

}
