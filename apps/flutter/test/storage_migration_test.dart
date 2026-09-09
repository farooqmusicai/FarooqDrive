import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:farooqdrive/storage_migration.dart';

void main() {
  test(
      'migration verifies and moves only app data; reinstall stays disconnected',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('farooqdrive-migration-test-');
    addTearDown(() => temp.delete(recursive: true));
    final old = await Directory('${temp.path}/old').create();
    final fresh = Directory('${temp.path}/new');
    await File('${old.path}/flutter_secure_storage.dat')
        .writeAsBytes([1, 2, 255]);
    await File('${old.path}/shared_preferences.json')
        .writeAsString('{"flutter.setting":true}');
    final unrelated =
        await File('${old.path}/unrelated.txt').writeAsString('keep');
    await migrateLegacyStorage(fresh, [old]);
    expect(await File('${fresh.path}/flutter_secure_storage.dat').readAsBytes(),
        [1, 2, 255]);
    expect(
        await File('${old.path}/flutter_secure_storage.dat').exists(), false);
    expect(await unrelated.readAsString(), 'keep');
    await fresh.delete(recursive: true);
    await migrateLegacyStorage(fresh, [old]);
    expect(
        await File('${fresh.path}/flutter_secure_storage.dat').exists(), false);
    expect(await File('${fresh.path}/shared_preferences.json').exists(), false);
  });

  test('migration never overwrites newer settings', () async {
    final temp =
        await Directory.systemTemp.createTemp('farooqdrive-migration-test-');
    addTearDown(() => temp.delete(recursive: true));
    final old = await Directory('${temp.path}/old').create();
    final fresh = await Directory('${temp.path}/new').create();
    await File('${old.path}/shared_preferences.json').writeAsString('old');
    await File('${fresh.path}/shared_preferences.json').writeAsString('new');
    await migrateLegacyStorage(fresh, [old]);
    expect(await File('${fresh.path}/shared_preferences.json').readAsString(),
        'new');
  });
}
