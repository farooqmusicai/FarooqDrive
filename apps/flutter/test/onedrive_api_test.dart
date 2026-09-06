import 'dart:convert';
import 'dart:typed_data';

import 'package:farooqdrive/cloud_drive_api.dart';
import 'package:farooqdrive/models.dart';
import 'package:farooqdrive/onedrive_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final account = DriveAccount(id: 'onedrive:test', email: 'test@example.invalid',
    name: 'Test', accessToken: 'old', provider: CloudProviderType.onedrive);
  Future<String> token(DriveAccount account, {bool force = false}) async => force ? 'new' : 'old';

  test('OneDrive paging parses folders and blocks untrusted next links', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.host, 'graph.microsoft.com');
      return http.Response(jsonEncode({
        'value': [{'id': 'folder', 'name': 'Folder', 'folder': {}}],
        '@odata.nextLink': 'https://unexpected.example.invalid/v1.0/steal',
      }), 200);
    });
    addTearDown(client.close);
    final api = OneDriveApi(tokenResolver: token, client: client);
    await expectLater(api.listFolder(account, 'root'), throwsA(isA<DriveApiException>()));
    expect(calls, 1);
    final folder = OneDriveApi.parseItem({'id': 'f', 'folder': {}}, account);
    expect(folder.isFolder, isTrue);
    expect(folder.canDownload, isFalse);
  });

  test('quota refresh retries 401 once with renewed token', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) return http.Response('{}', 401);
      expect(request.headers['Authorization'], 'Bearer new');
      return http.Response(jsonEncode({'id': 'drive', 'quota': {'total': 100, 'used': 20}}), 200);
    });
    addTearDown(client.close);
    final api = OneDriveApi(tokenResolver: token, client: client);
    final updated = await api.refreshQuota(account);
    expect(calls, 2);
    expect(updated.storageLimit, 100);
    expect(updated.storageUsed, 20);
    expect(updated.providerDriveId, 'drive');
  });

  test('download redirect receives no Graph bearer token', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'graph.microsoft.com') {
        expect(request.headers['Authorization'], 'Bearer old');
        expect(request.followRedirects, isFalse);
        return http.Response('', 302, headers: {'location': 'https://download.example.invalid/file'});
      }
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response.bytes([1, 2, 3], 200);
    });
    addTearDown(client.close);
    final api = OneDriveApi(tokenResolver: token, client: client);
    final item = OneDriveApi.parseItem({'id': 'f', 'size': 3, 'file': {}}, account);
    expect(await api.downloadBytes(account, item), [1, 2, 3]);
    await expectLater(api.setTrashed(account, 'f', true), throwsA(isA<DriveApiException>()));
    await expectLater(api.move(account, item, 'root'), throwsA(isA<DriveApiException>()));
  });

  test('conditional cleanup sends If-Match and stops on version conflict', () async {
    final client = MockClient((request) async {
      expect(request.method, 'DELETE');
      expect(request.headers['If-Match'], 'etag-1');
      expect(request.followRedirects, isFalse);
      return http.Response('', 412);
    });
    addTearDown(client.close);
    final api = OneDriveApi(tokenResolver: token, client: client);
    final item = OneDriveApi.parseItem({'id': 'f', 'size': 3, 'file': {}}, account);
    await expectLater(api.trashUnchanged(account, TransferSnapshot(item, 'etag-1', trashTag: 'etag-1')),
      throwsA(isA<DriveApiException>().having((error) => error.statusCode, 'status', 412)));
  });

  test('upload session never receives Graph token and creates a renamed copy', () async {
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        expect(request.url.host, 'graph.microsoft.com');
        expect(((jsonDecode(request.body) as Map)['item'] as Map)['@microsoft.graph.conflictBehavior'], 'rename');
        return http.Response(jsonEncode({'uploadUrl': 'https://upload.example.invalid/session'}), 200);
      }
      expect(request.headers.containsKey('Authorization'), false);
      expect(request.headers['Content-Range'], 'bytes 0-2/3');
      expect(request.bodyBytes, [1,2,3]);
      return http.Response('{"id":"new"}', 201);
    });
    addTearDown(client.close);
    final api = OneDriveApi(tokenResolver: token, client: client);
    expect(await api.uploadTransfer(account, 'root', 'file', 'application/octet-stream', 3,
      (start,end) async => Uint8List.fromList([1,2,3])), 'new');
  });
}
