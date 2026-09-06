import 'dart:typed_data';
import 'cloud_drive_api.dart';

class TransferSpool {
  static String get cachePath => 'Windows temporary storage';
  static Future<TransferSpool> create() async => throw const DriveApiException('Disk-backed transfers are available in the desktop app.');
  int get length => 0;
  String get digest => '';
  Future<void> write(Stream<List<int>> stream, int? expected, void Function(int) progress) async {}
  Future<Uint8List> readRange(int start, int end) async => Uint8List(0);
  Future<void> close() async {}
}
