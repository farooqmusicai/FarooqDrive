import 'package:flutter_test/flutter_test.dart';
import '../lib/transfer_spool_stub.dart';
import '../lib/cloud_drive_api.dart';

void main() {
  test('browser staging hashes content and supports upload ranges then clears', () async {
    final spool = await TransferSpool.create();
    await spool.write(Stream.fromIterable([[97], [98, 99]]), 3, (_) {});
    expect(spool.digest, 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(await spool.readRange(1, 3), [98, 99]);
    await spool.close();
    expect(spool.length, 0);
    expect(spool.digest, isEmpty);
  });
  test('rejects known oversized and incomplete downloads', () async {
    final spool = await TransferSpool.create();
    await expectLater(spool.write(const Stream.empty(), TransferSpool.limit + 1, (_) {}), throwsA(isA<DriveApiException>()));
    await expectLater(spool.write(Stream.value([1]), 2, (_) {}), throwsA(isA<DriveApiException>()));
    expect(spool.length, 0);
  });
  test('unknown size cannot bypass browser memory bound', () async {
    final spool = await TransferSpool.create();
    final chunk = List<int>.filled(1024 * 1024, 0);
    await expectLater(spool.write(Stream.fromIterable(List.filled(33, chunk)), null, (_) {}), throwsA(isA<DriveApiException>()));
    expect(spool.length, 0);
  });
}
