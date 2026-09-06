import 'dart:typed_data';

import 'models.dart';

class DriveApiException implements Exception {
  const DriveApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

// Compatibility transport for existing Google operations. Large-file support
// will require a separate disk-backed streaming transport before release.
class TransferFile {
  const TransferFile(this.name, this.mimeType, this.bytes);
  final String name;
  final String mimeType;
  final Uint8List bytes;
}

/// Provider boundary. Source-cleanup confirmation belongs to the controller's
/// transfer state machine, not to these low-level provider operations.
abstract class CloudDriveApi {
  CloudProviderType get providerType;
  String get rootFolderId;
  String get rootFolderLabel;

  Future<List<DriveItem>> listFolder(DriveAccount account, String folderId);
  Future<List<DriveItem>> listAllFiles(DriveAccount account);
  Future<DriveAccount> refreshQuota(DriveAccount account);
  Future<String> createFolder(
    DriveAccount account, String parentId, String name,
  );
  Future<void> rename(DriveAccount account, String id, String name);
  Future<void> setTrashed(DriveAccount account, String id, bool trashed);
  Future<String> copy(
    DriveAccount account, DriveItem item, String parentId,
  );
  Future<void> move(
    DriveAccount account, DriveItem item, String parentId,
  );
  Future<String> uploadBytes(
    DriveAccount account, {
    required String parentId,
    required String name,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
  });
  Future<bool> verifyUploadedFile(
    DriveAccount account, String fileId, int expectedSize,
  );
  Future<Uint8List> downloadBytes(DriveAccount account, DriveItem item);
  Future<TransferFile> downloadForTransfer(
    DriveAccount account, DriveItem item,
  );
}
