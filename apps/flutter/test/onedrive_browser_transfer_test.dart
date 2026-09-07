import 'dart:convert';
import 'package:farooqdrive/cloud_drive_api.dart';
import 'package:farooqdrive/models.dart';
import 'package:farooqdrive/onedrive_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final account = DriveAccount(id: 'onedrive:test', email: 'test@example.invalid',
      name: 'Test', accessToken: 'private-token', provider: CloudProviderType.onedrive);
  final item = DriveItem(id: 'file1', name: 'demo.txt', size: 3,
      accountId: account.id, accountEmail: account.email,
      mimeType: 'text/plain', isFolder: false);
  Future<String> token(DriveAccount account, {bool force = false}) async => 'private-token';

  test('full metadata supplies annotation omitted by a narrow projection; content has no bearer', () async {
    final calls = <Uri>[];
    final client = MockClient((request) async {
      calls.add(request.url);
      if (request.url.host == 'graph.microsoft.com') {
        expect(request.url.query, isEmpty);
        expect(request.headers['Authorization'], 'Bearer private-token');
        return http.Response(jsonEncode({'id':'file1', '@microsoft.graph.downloadUrl':'https://content.example.invalid/demo?auth=temporary'}), 200);
      }
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response('abc', 200);
    });
    addTearDown(client.close);
    final api = OneDriveApi(tokenResolver: token, client: client, browserDownloads: true);
    final result = await api.openTransfer(account, item);
    expect(await result.stream.expand((chunk) => chunk).toList(), [97,98,99]);
    expect(calls.length, 2);
    expect(calls.any((uri) => uri.path.endsWith('/content')), isFalse);
  });

  test('missing default annotation retries documented select form', () async {
    var metadataCalls = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'graph.microsoft.com') {
        metadataCalls++;
        if (metadataCalls == 1) return http.Response('{"id":"file1"}', 200);
        expect(request.url.queryParameters['select'], 'id,@microsoft.graph.downloadUrl');
        return http.Response('{"id":"file1","@microsoft.graph.downloadUrl":"https://content.example.invalid/demo"}', 200);
      }
      return http.Response('abc', 200);
    });
    addTearDown(client.close);
    final api = OneDriveApi(tokenResolver: token, client: client, browserDownloads: true);
    final result = await api.openTransfer(account, item);
    await result.stream.drain<void>();
    expect(metadataCalls, 2);
  });

  test('missing link stops after metadata without uploading or content redirect', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.method, 'GET');
      expect(request.url.host, 'graph.microsoft.com');
      expect(request.url.path.endsWith('/content'), isFalse);
      return http.Response('{"id":"file1"}', 200);
    });
    addTearDown(client.close);
    final api = OneDriveApi(tokenResolver: token, client: client, browserDownloads: true);
    await expectLater(api.openTransfer(account, item), throwsA(isA<DriveApiException>()));
    expect(calls, 2);
  });

  for (final data in [
    {'id':'different','@microsoft.graph.downloadUrl':'https://content.example.invalid/demo'},
    {'id':'file1','@microsoft.graph.downloadUrl':'http://content.example.invalid/demo'},
    {'id':'file1','@microsoft.graph.downloadUrl':'https://user:secret@content.example.invalid/demo'},
  ]) {
    test('rejects wrong file or unsafe URL: ${data['id']} ${data['@microsoft.graph.downloadUrl']}', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(jsonEncode(data), 200);
      });
      addTearDown(client.close);
      final api = OneDriveApi(tokenResolver: token, client: client, browserDownloads: true);
      await expectLater(api.openTransfer(account, item), throwsA(isA<DriveApiException>()));
      expect(calls, 1);
    });
  }
}
