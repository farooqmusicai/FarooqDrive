import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'cloud_drive_api.dart';
import 'app_storage_windows.dart';

/// Each operation owns one OS-created unique directory. Never deletes siblings.
class TransferSpool {
  TransferSpool._(this.directory, this.file);
  final Directory directory;
  final File file;
  static String get cachePath => '${AppStorage.cache}${Platform.pathSeparator}Transfers';
  static Future<TransferSpool> create() async {
    final root = await Directory(cachePath).create(recursive: true);
    final directory = await root.createTemp('job-');
    return TransferSpool._(directory, File('${directory.path}${Platform.pathSeparator}payload'));
  }
  int length = 0;
  String digest = '';
  Future<void> write(Stream<List<int>> stream, int? expected, void Function(int) progress) async {
    final output = await file.open(mode: FileMode.write);
    try {
      await for (final bytes in stream.timeout(const Duration(seconds: 60))) {
        length += bytes.length;
        if (length > 1024 * 1024 * 1024) throw const DriveApiException('Private Windows transfer limit is 1 GiB per file. Source retained.');
        await output.writeFrom(bytes);
        progress(length);
      }
      await output.flush();
    } finally {
      await output.close();
    }
    if (expected != null && length != expected) throw const DriveApiException('Incomplete download or source size changed. Source retained.');
    digest = (await sha256.bind(file.openRead()).first).toString();
  }
  Future<Uint8List> readRange(int start, int end) async {
    final input = await file.open();
    try {
      await input.setPosition(start);
      final bytes = await input.read(end - start);
      if (bytes.length != end - start) throw const DriveApiException('Temporary transfer file is incomplete.');
      return bytes;
    } finally { await input.close(); }
  }
  Future<void> close() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
