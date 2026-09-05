const googleFolderMime = 'application/vnd.google-apps.folder';

class DriveAccount {
  DriveAccount({
    required this.id,
    required this.email,
    required this.name,
    required this.accessToken,
    this.photoUrl,
    this.storageUsed = 0,
    this.storageLimit,
  });

  final String id;
  final String email;
  final String name;
  final String accessToken;
  final String? photoUrl;
  final int storageUsed;
  final int? storageLimit;

  DriveAccount copyWith({int? storageUsed, int? storageLimit}) => DriveAccount(
        id: id,
        email: email,
        name: name,
        accessToken: accessToken,
        photoUrl: photoUrl,
        storageUsed: storageUsed ?? this.storageUsed,
        storageLimit: storageLimit ?? this.storageLimit,
      );
}

class DriveItem {
  const DriveItem({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.accountId,
    required this.accountEmail,
    this.size,
    this.modifiedTime,
    this.webViewLink,
    this.parents = const [],
    this.canDownload = true,
    this.location = 'My Drive',
  });

  final String id;
  final String name;
  final String mimeType;
  final String accountId;
  final String accountEmail;
  final int? size;
  final DateTime? modifiedTime;
  final String? webViewLink;
  final List<String> parents;
  final bool canDownload;
  final String location;

  bool get isFolder => mimeType == googleFolderMime;

  DriveItem copyWithLocation(String value) => DriveItem(
        id: id,
        name: name,
        mimeType: mimeType,
        accountId: accountId,
        accountEmail: accountEmail,
        size: size,
        modifiedTime: modifiedTime,
        webViewLink: webViewLink,
        parents: parents,
        canDownload: canDownload,
        location: value,
      );

  factory DriveItem.fromJson(
    Map<String, dynamic> json, {
    required DriveAccount account,
  }) =>
      DriveItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Untitled',
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        accountId: account.id,
        accountEmail: account.email,
        size: int.tryParse('${json['size'] ?? ''}'),
        modifiedTime: DateTime.tryParse('${json['modifiedTime'] ?? ''}'),
        webViewLink: json['webViewLink'] as String?,
        parents: (json['parents'] as List?)?.cast<String>() ?? const [],
        canDownload:
            (json['capabilities'] as Map?)?['canDownload'] as bool? ?? true,
      );
}

class FolderCrumb {
  const FolderCrumb(this.id, this.name);
  final String id;
  final String name;
}

enum ClipboardMode { copy, move }

enum FileViewMode { all, exactDuplicates, nameConflicts }

class DriveClipboard {
  const DriveClipboard(this.mode, this.items);
  final ClipboardMode mode;
  final List<DriveItem> items;
}
