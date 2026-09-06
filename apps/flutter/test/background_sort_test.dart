import 'dart:async';
import 'package:farooqdrive/drive_controller.dart';
import 'package:farooqdrive/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'controller_provider_test.dart' show RecordingApi, account;

class SlowApi extends RecordingApi {
  SlowApi() : super(CloudProviderType.google);
  final done = Completer<List<DriveItem>>();
  @override
  Future<List<DriveItem>> listAllFiles(DriveAccount account) => done.future;
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
    expect(c.loading, isFalse);
    await c.selectAccount('g');
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
}
