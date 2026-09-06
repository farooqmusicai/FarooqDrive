import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'cloud_drive_api.dart';
import 'models.dart';

typedef MicrosoftTokenResolver = Future<String> Function(DriveAccount account, {bool force});

/// Private read-only milestone. Mutations remain blocked until verified
/// transfers and final source-cleanup confirmation are implemented.
class OneDriveApi implements CloudDriveApi {
  OneDriveApi({required MicrosoftTokenResolver tokenResolver, http.Client? client})
      : _tokenResolver = tokenResolver, _client = client ?? http.Client();
  final MicrosoftTokenResolver _tokenResolver;
  final http.Client _client;
  static const _base = 'https://graph.microsoft.com/v1.0';
  static const privateDownloadLimit = 32 * 1024 * 1024;
  @override
  CloudProviderType get providerType => CloudProviderType.onedrive;
  @override
  String get rootFolderId => 'root';
  @override
  String get rootFolderLabel => 'OneDrive';

  static String _item(String id) => id == 'root' ? 'root' : 'items/${Uri.encodeComponent(id)}';

  Future<http.Response> _get(DriveAccount account, Uri uri) async {
    if (uri.scheme != 'https' || uri.host != 'graph.microsoft.com' ||
        uri.port != 443 || uri.userInfo.isNotEmpty || !uri.path.startsWith('/v1.0/')) {
      throw const DriveApiException('Microsoft returned an unexpected paging URL.');
    }
    var refreshed = false;
    var token = await _tokenResolver(account, force: false);
    for (var attempt = 0; attempt < 4; attempt++) {
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..headers['Authorization'] = 'Bearer $token';
      final streamed = await _client.send(request).timeout(const Duration(seconds: 45));
      final payload = BytesBuilder(copy: false);
      await for (final chunk in streamed.stream.timeout(const Duration(seconds: 45))) {
        if (payload.length + chunk.length > 4 * 1024 * 1024) {
          throw const DriveApiException('Unexpectedly large Microsoft metadata response.');
        }
        payload.add(chunk);
      }
      final response = http.Response.bytes(payload.takeBytes(), streamed.statusCode, headers: streamed.headers);
      if (response.statusCode == 401 && !refreshed) {
        token = await _tokenResolver(account, force: true);
        refreshed = true;
        continue;
      }
      if ((response.statusCode == 429 || response.statusCode == 503) && attempt < 3) {
        final seconds = int.tryParse(response.headers['retry-after'] ?? '') ?? (1 << attempt);
        if (seconds < 0 || seconds > 30) {
          throw const DriveApiException('OneDrive is busy. Please retry later.');
        }
        await Future<void>.delayed(Duration(seconds: seconds));
        continue;
      }
      if (response.statusCode >= 200 && response.statusCode < 400) return response;
      String code = '';
      try {
        final error = (jsonDecode(response.body) as Map)['error'] as Map?;
        final rawCode = error?['code'];
        if (rawCode is String && RegExp(r'^[A-Za-z0-9_]{1,80}$').hasMatch(rawCode)) code = rawCode;
      } catch (_) {}
      throw DriveApiException('OneDrive request failed (${response.statusCode}${code.isEmpty ? '' : ': $code'}). Check sign-in, permissions or account availability.', statusCode: response.statusCode);
    }
    throw const DriveApiException('OneDrive retry limit reached. Please retry later.');
  }

  Future<Map<String, dynamic>> _json(DriveAccount account, Uri uri) async {
    final response = await _get(account, uri);
    if (response.statusCode != 200) throw const DriveApiException('Unexpected OneDrive response.');
    try { return jsonDecode(response.body) as Map<String, dynamic>; }
    catch (_) { throw const DriveApiException('OneDrive returned unreadable metadata.'); }
  }

  static DriveItem parseItem(Map<String, dynamic> data, DriveAccount account) {
    final folder = data['folder'] is Map;
    final file = data['file'] as Map?;
    final parent = data['parentReference'] as Map?;
    // Shared remote items and packages need dedicated handling in a later gate.
    final remote = data['remoteItem'] != null;
    return DriveItem(id: data['id'] as String, name: data['name'] as String? ?? 'Untitled',
      isFolder: folder, mimeType: file?['mimeType'] as String? ?? 'application/octet-stream',
      accountId: account.id, accountEmail: account.email,
      size: (data['size'] as num?)?.toInt(),
      modifiedTime: DateTime.tryParse('${data['lastModifiedDateTime'] ?? ''}'),
      parents: [if (parent?['id'] is String) parent!['id'] as String],
      webViewLink: data['webUrl'] as String?, canDownload: file != null && !remote,
      ownedByMe: !remote, location: 'OneDrive');
  }

  @override
  Future<List<DriveItem>> listFolder(DriveAccount account, String folderId) async {
    Uri? uri = Uri.parse('$_base/me/drive/${_item(folderId)}/children').replace(queryParameters: {
      r'$top': '200', r'$select': 'id,name,size,folder,file,parentReference,lastModifiedDateTime,webUrl,remoteItem,package',
    });
    final seen = <String>{};
    final items = <DriveItem>[];
    while (uri != null) {
      if (!seen.add(uri.toString())) throw const DriveApiException('OneDrive repeated a result page. Retry refresh.');
      final data = await _json(account, uri);
      items.addAll((data['value'] as List? ?? []).map((value) => parseItem(value as Map<String, dynamic>, account)));
      final next = data['@odata.nextLink'] as String?;
      uri = next == null ? null : Uri.parse(next);
    }
    return items;
  }

  @override
  Future<List<DriveItem>> listAllFiles(DriveAccount account) async {
    final queue = Queue<String>()..add(rootFolderId);
    final visited = <String>{};
    final items = <DriveItem>[];
    while (queue.isNotEmpty) {
      final id = queue.removeFirst();
      if (!visited.add(id)) continue;
      final children = await listFolder(account, id);
      items.addAll(children);
      queue.addAll(children.where((item) => item.isFolder && item.ownedByMe).map((item) => item.id));
    }
    return items;
  }

  @override
  Future<DriveAccount> refreshQuota(DriveAccount account) async {
    final data = await _json(account, Uri.parse('$_base/me/drive').replace(queryParameters: {
      r'$select': 'id,driveType,quota',
    }));
    final quota = data['quota'] as Map? ?? {};
    final total = (quota['total'] as num?)?.toInt();
    return account.copyWith(storageUsed: (quota['used'] as num?)?.toInt() ?? 0,
      storageLimit: total != null && total > 0 ? total : null,
      providerDriveId: data['id'] as String?);
  }

  @override
  Future<Uint8List> downloadBytes(DriveAccount account, DriveItem item) async {
    if (item.isFolder || !item.canDownload) throw const DriveApiException('Open this item on the provider website.');
    if (item.size == null || item.size! > privateDownloadLimit) {
      throw const DriveApiException('This private OneDrive test supports downloads up to 32 MiB with a known size. Larger downloads will use the upcoming disk cache.');
    }
    final metadata = await _get(account, Uri.parse('$_base/me/drive/items/${Uri.encodeComponent(item.id)}/content'));
    final location = metadata.headers['location'];
    if (metadata.statusCode != 302 || location == null) throw const DriveApiException('OneDrive did not return a download link.');
    var uri = Uri.parse(location);
    for (var redirects = 0; redirects < 5; redirects++) {
      if (uri.scheme != 'https' || uri.userInfo.isNotEmpty) throw const DriveApiException('Invalid OneDrive download link.');
      // Pre-authenticated URL: never forward the Graph bearer token.
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await _client.send(request).timeout(const Duration(seconds: 45));
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        await response.stream.drain<void>();
        final next = response.headers['location'];
        if (next == null) break;
        uri = uri.resolve(next);
        continue;
      }
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw const DriveApiException('OneDrive download failed. Retry the download.');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(const Duration(seconds: 45))) {
        if (bytes.length + chunk.length > privateDownloadLimit) throw const DriveApiException('Download exceeded the private-test size limit.');
        bytes.add(chunk);
      }
      if (bytes.length != item.size) throw const DriveApiException('Download size changed or was incomplete. Refresh and retry.');
      return bytes.takeBytes();
    }
    throw const DriveApiException('Too many OneDrive download redirects.');
  }

  Never _readOnly() => throw const DriveApiException('OneDrive is read-only in this private test. Upload, Copy, Move and Trash will follow after safety verification.');
  @override
  Future<String> createFolder(DriveAccount account, String parentId, String name) async => _readOnly();
  @override
  Future<void> rename(DriveAccount account, String id, String name) async => _readOnly();
  @override
  Future<void> setTrashed(DriveAccount account, String id, bool trashed) async => _readOnly();
  @override
  Future<String> copy(DriveAccount account, DriveItem item, String parentId) async => _readOnly();
  @override
  Future<void> move(DriveAccount account, DriveItem item, String parentId) async => _readOnly();
  @override
  Future<String> uploadBytes(DriveAccount account, {required String parentId, required String name,
    required Uint8List bytes, String mimeType = 'application/octet-stream'}) async => _readOnly();
  @override
  Future<bool> verifyUploadedFile(DriveAccount account, String fileId, int expectedSize) async => _readOnly();
  @override
  Future<TransferFile> downloadForTransfer(DriveAccount account, DriveItem item) async => _readOnly();
}
