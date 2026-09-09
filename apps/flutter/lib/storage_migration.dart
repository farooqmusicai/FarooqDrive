import 'dart:io';

/// Moves only the two known FarooqDrive data files. No cloud data is touched.
/// A reinstall cannot restore accounts from these legacy files after migration.
Future<void> migrateLegacyStorage(
    Directory destination, List<Directory> sources) async {
  await destination.create(recursive: true);
  const names = ['shared_preferences.json', 'flutter_secure_storage.dat'];
  for (var sourceIndex = 0; sourceIndex < sources.length; sourceIndex++) {
    final source = sources[sourceIndex];
    if (source.absolute.path == destination.absolute.path) continue;
    for (final name in names) {
      final oldFile = File('${source.path}${Platform.pathSeparator}$name');
      if (!await oldFile.exists()) continue;
      var newFile = File('${destination.path}${Platform.pathSeparator}$name');
      if (await newFile.exists()) {
        // Keep any older conflicting file inside the same uninstall boundary.
        // It is never read as current state or imported on a later reinstall.
        final archive = await Directory('${destination.path}${Platform.pathSeparator}Legacy').create();
        newFile = File('${archive.path}${Platform.pathSeparator}$sourceIndex-$name');
      }
      final bytes = await oldFile.readAsBytes();
      final staging = File('${newFile.path}.migrating');
      await staging.writeAsBytes(bytes, flush: true);
      final written = await staging.readAsBytes();
      if (written.length != bytes.length ||
          Iterable<int>.generate(bytes.length)
              .any((i) => bytes[i] != written[i])) {
        throw StateError('Could not verify migrated app settings.');
      }
      await staging.rename(newFile.path);
      await oldFile.delete();
    }
  }
}
