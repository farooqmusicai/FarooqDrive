import 'dart:convert';

import 'package:farooqdrive/cloud_drive_api.dart';
import 'package:farooqdrive/google_drive_api.dart';
import 'package:farooqdrive/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  DriveAccount googleAccount() => DriveAccount(
        id: 'legacy-google-id',
        email: 'test@example.invalid',
        name: 'Test',
        accessToken: 'test-token',
      );

  test('legacy Google account identity survives quota and token updates', () {
    final original = googleAccount();
    final updated = original.copyWith(accessToken: 'new-token', storageUsed: 42);
    expect(updated.provider, CloudProviderType.google);
    expect(updated.id, original.id);
    expect(updated.storageUsed, 42);
    expect(updated.accessToken, 'new-token');
  });

  test('Microsoft account identity survives common account updates', () {
    final account = DriveAccount(
      id: 'onedrive:test-id',
      email: 'test@example.invalid',
      name: 'Test',
      accessToken: 'test-token',
      provider: CloudProviderType.onedrive,
      providerDriveId: 'test-drive',
    ).copyWith(storageUsed: 42);
    expect(account.provider, CloudProviderType.onedrive);
    expect(account.providerDriveId, 'test-drive');
    expect(account.oauthClientSecret, isNull);
  });

  test('non-Google folders remain folders after adding a display path', () {
    const item = DriveItem(
      id: 'folder',
      name: 'Folder',
      mimeType: 'application/octet-stream',
      isFolder: true,
      accountId: 'onedrive:test-id',
      accountEmail: 'test@example.invalid',
    );
    expect(item.copyWithLocation('OneDrive / Folder').isFolder, isTrue);
  });

  test('Google paging and folder parsing work through shared API', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.url.queryParameters['q'], "'root' in parents and trashed=false");
      if (calls == 1) {
        expect(request.url.queryParameters['pageToken'], isNull);
        return http.Response(jsonEncode({
          'nextPageToken': 'second-page',
          'files': [{'id': 'folder', 'name': 'Folder', 'mimeType': googleFolderMime}],
        }), 200);
      }
      expect(request.url.queryParameters['pageToken'], 'second-page');
      return http.Response(jsonEncode({
        'files': [{'id': 'file', 'name': 'File', 'size': '42'}],
      }), 200);
    });
    addTearDown(client.close);
    final CloudDriveApi api = GoogleDriveApi(client: client);
    final items = await api.listFolder(googleAccount(), api.rootFolderId);
    expect(calls, 2);
    expect(items.length, 2);
    expect(items.first.isFolder, isTrue);
    expect(items.last.isFolder, isFalse);
    expect(items.last.size, 42);
    expect(items.last.accountId, 'legacy-google-id');
  });
}
