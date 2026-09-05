import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

class DriveApiException implements Exception {
  const DriveApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class TransferFile {
  const TransferFile(this.name, this.mimeType, this.bytes);
  final String name;
  final String mimeType;
  final Uint8List bytes;
}

class GoogleDriveApi {
  GoogleDriveApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _api = 'https://www.googleapis.com/drive/v3';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3';

  Future<Map<String, dynamic>> _json(
    DriveAccount account,
    String url, {
    String method = 'GET',
    Map<String, String>? headers,
    Object? body,
  }) async {
    final request = http.Request(method, Uri.parse(url))
      ..headers.addAll({
        'Authorization': 'Bearer ${account.accessToken}',
        ...?headers,
      });
    if (body != null) request.body = body is String ? body : jsonEncode(body);
    final response = await http.Response.fromStream(await _client.send(request));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Google Drive request failed (${response.statusCode})';
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        message = ((decoded['error'] as Map?)?['message'] as String?) ?? message;
      } catch (_) {}
      throw DriveApiException(message, statusCode: response.statusCode);
    }
    if (response.bodyBytes.isEmpty) return const {};
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<List<DriveItem>> listFolder(
    DriveAccount account,
    String folderId,
  ) async {
    final items = <DriveItem>[];
    String? pageToken;
    do {
      final query = <String, String>{
        'q': "'$folderId' in parents and trashed=false",
        'pageSize': '1000',
        'orderBy': 'folder,name_natural',
        'fields':
            'nextPageToken,files(id,name,mimeType,size,modifiedTime,webViewLink,parents,capabilities(canDownload))',
        if (pageToken != null) 'pageToken': pageToken,
      };
      final uri = Uri.parse('$_api/files').replace(queryParameters: query);
      final data = await _json(account, uri.toString());
      items.addAll((data['files'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map((json) => DriveItem.fromJson(json, account: account)));
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return items;
  }

  Future<List<DriveItem>> listAllFiles(DriveAccount account) async {
    final items = <DriveItem>[];
    String? pageToken;
    do {
      final query = <String, String>{
        'q': 'trashed=false',
        'spaces': 'drive',
        'pageSize': '1000',
        'fields':
            'nextPageToken,files(id,name,mimeType,size,modifiedTime,webViewLink,parents,capabilities(canDownload))',
        if (pageToken != null) 'pageToken': pageToken,
      };
      final uri = Uri.parse('$_api/files').replace(queryParameters: query);
      final data = await _json(account, uri.toString());
      items.addAll((data['files'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map((json) => DriveItem.fromJson(json, account: account)));
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return items;
  }

  Future<DriveAccount> refreshQuota(DriveAccount account) async {
    final uri = Uri.parse('$_api/about').replace(
      queryParameters: const {
        'fields': 'storageQuota(limit,usage,usageInDrive,usageInDriveTrash)',
      },
    );
    final data = await _json(account, uri.toString());
    final quota = data['storageQuota'] as Map<String, dynamic>? ?? const {};
    return account.copyWith(
      storageUsed: int.tryParse('${quota['usageInDrive'] ?? quota['usage'] ?? 0}') ?? 0,
      storageLimit: int.tryParse('${quota['limit'] ?? ''}'),
    );
  }

  Future<String> createFolder(
    DriveAccount account,
    String parentId,
    String name,
  ) async {
    final data = await _json(
      account,
      '$_api/files?fields=id',
      method: 'POST',
      headers: const {'Content-Type': 'application/json'},
      body: {
        'name': name,
        'mimeType': googleFolderMime,
        'parents': [parentId],
      },
    );
    return data['id'] as String;
  }

  Future<void> rename(DriveAccount account, String id, String name) async {
    await _json(
      account,
      '$_api/files/${Uri.encodeComponent(id)}?fields=id',
      method: 'PATCH',
      headers: const {'Content-Type': 'application/json'},
      body: {'name': name},
    );
  }

  Future<void> setTrashed(
    DriveAccount account,
    String id,
    bool trashed,
  ) async {
    await _json(
      account,
      '$_api/files/${Uri.encodeComponent(id)}?fields=id',
      method: 'PATCH',
      headers: const {'Content-Type': 'application/json'},
      body: {'trashed': trashed},
    );
  }

  Future<String> copy(
    DriveAccount account,
    DriveItem item,
    String parentId,
  ) async {
    final data = await _json(
      account,
      '$_api/files/${Uri.encodeComponent(item.id)}/copy?fields=id',
      method: 'POST',
      headers: const {'Content-Type': 'application/json'},
      body: {
        'name': item.name,
        'parents': [parentId],
      },
    );
    return data['id'] as String;
  }

  Future<void> move(
    DriveAccount account,
    DriveItem item,
    String parentId,
  ) async {
    final uri = Uri.parse('$_api/files/${Uri.encodeComponent(item.id)}').replace(
      queryParameters: {
        'addParents': parentId,
        if (item.parents.isNotEmpty) 'removeParents': item.parents.join(','),
        'fields': 'id,parents',
      },
    );
    await _json(account, uri.toString(), method: 'PATCH');
  }

  Future<String> uploadBytes(
    DriveAccount account, {
    required String parentId,
    required String name,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
  }) async {
    final boundary = 'farooqdrive-${DateTime.now().microsecondsSinceEpoch}';
    // MultipartRequest uses form-data, while Drive expects multipart/related.
    // Build the related payload explicitly to keep web and desktop behavior equal.
    final metadata = utf8.encode(jsonEncode({'name': name, 'parents': [parentId]}));
    final payload = BytesBuilder()
      ..add(utf8.encode('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n'))
      ..add(metadata)
      ..add(utf8.encode('\r\n--$boundary\r\nContent-Type: $mimeType\r\n\r\n'))
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--'));
    final response = await http.post(
      Uri.parse('$_upload/files?uploadType=multipart&fields=id'),
      headers: {
        'Authorization': 'Bearer ${account.accessToken}',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: payload.takeBytes(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DriveApiException('Upload failed (${response.statusCode})',
          statusCode: response.statusCode);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['id'] as String;
  }

  Future<bool> verifyUploadedFile(
    DriveAccount account,
    String fileId,
    int expectedSize,
  ) async {
    final data = await _json(
      account,
      '$_api/files/${Uri.encodeComponent(fileId)}?fields=id,size,trashed',
    );
    return data['id'] == fileId &&
        data['trashed'] != true &&
        int.tryParse('${data['size'] ?? ''}') == expectedSize;
  }

  Future<Uint8List> downloadBytes(DriveAccount account, DriveItem item) async {
    final response = await _client.get(
      Uri.parse('$_api/files/${Uri.encodeComponent(item.id)}?alt=media'),
      headers: {'Authorization': 'Bearer ${account.accessToken}'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DriveApiException('Download failed (${response.statusCode})',
          statusCode: response.statusCode);
    }
    return response.bodyBytes;
  }

  Future<TransferFile> downloadForTransfer(
    DriveAccount account,
    DriveItem item,
  ) async {
    const exports = <String, (String, String)>{
      'application/vnd.google-apps.document': (
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        '.docx',
      ),
      'application/vnd.google-apps.spreadsheet': (
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        '.xlsx',
      ),
      'application/vnd.google-apps.presentation': (
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        '.pptx',
      ),
      'application/vnd.google-apps.drawing': ('image/png', '.png'),
    };
    final export = exports[item.mimeType];
    if (export == null) {
      return TransferFile(
        item.name,
        item.mimeType,
        await downloadBytes(account, item),
      );
    }
    final uri = Uri.parse(
      '$_api/files/${Uri.encodeComponent(item.id)}/export',
    ).replace(queryParameters: {'mimeType': export.$1});
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer ${account.accessToken}'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DriveApiException(
        'Google file export failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    final name = item.name.toLowerCase().endsWith(export.$2)
        ? item.name
        : '${item.name}${export.$2}';
    return TransferFile(name, export.$1, response.bodyBytes);
  }
}
