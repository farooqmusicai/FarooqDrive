import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'cloud_drive_api.dart';

/// Browser staging is memory-only and deliberately bounded.
class TransferSpool {
  static const limit = 32 * 1024 * 1024;
  static String get cachePath => 'temporary browser memory (32 MiB/file limit)';
  static Future<TransferSpool> create() async => TransferSpool();
  Uint8List _bytes = Uint8List(0);
  int get length => _bytes.length;
  String digest = '';
  Future<void> write(Stream<List<int>> stream, int? expected, void Function(int) progress) async {
    if (expected != null && (expected < 0 || expected > limit)) throw const DriveApiException('Web transfers support up to 32 MiB per file. Use Windows for larger files.');
    final chunks = BytesBuilder(copy:true);
    await for (final chunk in stream.timeout(const Duration(seconds: 60))) {
      if (chunks.length + chunk.length > limit) throw const DriveApiException('Web transfer exceeded the 32 MiB limit. Source retained.');
      chunks.add(chunk); progress(chunks.length);
    }
    if(expected != null && chunks.length != expected) throw const DriveApiException('Download was incomplete. Source retained.');
    _bytes=chunks.takeBytes(); digest=sha256.convert(_bytes).toString();
  }
  Future<Uint8List> readRange(int start,int end) async => Uint8List.sublistView(_bytes,start,end);
  Future<void> close() async { _bytes=Uint8List(0); digest=''; }
}
