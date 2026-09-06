import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'cloud_drive_api.dart';
import 'models.dart';
import 'transfer_spool.dart';

class VerifiedCopy {
  const VerifiedCopy(this.sourceAccount, this.source, this.destination, this.copy, this.digest);
  final DriveAccount sourceAccount;
  final TransferSnapshot source;
  final DriveAccount destination;
  final TransferSnapshot copy;
  final String digest;
}

/// A batch is completely copied and verified before cleanup is even offered.
/// Folder containers are never trashed: newly added children cannot be lost.
class VerifiedTransfer {
  VerifiedTransfer(this.provider, this.progress, this.checkCancelled);
  final CloudDriveApi Function(DriveAccount) provider;
  final void Function(String) progress;
  final void Function() checkCancelled;
  static const fileLimit = kIsWeb ? 32 * 1024 * 1024 : 1024 * 1024 * 1024;
  final List<VerifiedCopy> copies = [];
  int nativeCopies = 0;
  final Set<String> _seen = {};

  Future<_Plan> _plan(DriveAccount account, DriveItem item, int depth) async {
    checkCancelled();
    if (depth > 64 || _seen.length >= 10000 || !_seen.add('${account.id}:${item.id}')) {
      throw const DriveApiException('Overlapping selection, cycle or batch limit reached (10,000 items / 64 levels). Select a smaller non-overlapping batch.');
    }
    final snapshot = await provider(account).snapshot(account, item.id);
    final current = snapshot.item;
    if (!current.isFolder && (current.size ?? 0) > fileLimit) throw const DriveApiException(kIsWeb ? 'Web transfers support up to 32 MiB per file.' : 'Windows transfers support up to 1 GiB per file.');
    final children = <_Plan>[];
    if (current.isFolder) {
      for (final child in await provider(account).listFolder(account, current.id)) {
        children.add(await _plan(account, child, depth + 1));
      }
    }
    return _Plan(account, snapshot, children);
  }

  Future<void> run(List<(DriveAccount, DriveItem)> items, DriveAccount destination, String parent) async {
    final plans = <_Plan>[];
    progress('Checking source files and folders…');
    for (final entry in items) { plans.add(await _plan(entry.$1, entry.$2, 0)); }
    if (_seen.contains('${destination.id}:$parent')) throw const DriveApiException('Cannot paste into the source folder or its descendants.');
    for (final entry in plans) { await _copy(entry, destination, parent); }
  }

  Future<void> _copy(_Plan plan, DriveAccount destination, String parent) async {
    checkCancelled();
    final source = plan.snapshot;
    final api = provider(plan.account);
    final targetApi = provider(destination);
    if (source.item.isFolder) {
      final id = await targetApi.createFolder(destination, parent, source.item.name);
      for (final child in plan.children) { await _copy(child, destination, id); }
      final actual = await targetApi.listFolder(destination, id);
      if (actual.length != plan.children.length) throw const DriveApiException('Destination folder contents differ. Source retained.');
      return;
    }
    if (plan.account.id == destination.id && destination.provider == CloudProviderType.google &&
        source.item.mimeType.startsWith('application/vnd.google-apps.')) {
      // Preserve Google-native formats for existing within-account Copy behavior.
      // These are explicitly not counted as byte-verified or eligible for cleanup.
      progress('Copying Google-native file ${source.item.name}…');
      final id = await api.copy(plan.account, source.item, parent);
      final copy = await api.snapshot(destination, id);
      if (copy.item.mimeType != source.item.mimeType) throw const DriveApiException('Google-native copy type differs. Source retained.');
      nativeCopies++;
      return;
    }
    final spool = await TransferSpool.create();
    try {
      progress('Downloading ${source.item.name} to ${TransferSpool.cachePath}…');
      final download = await api.openTransfer(plan.account, source.item);
      var lastUpdate = DateTime.now();
      await spool.write(download.stream, download.length, (bytes) {
        checkCancelled();
        if (DateTime.now().difference(lastUpdate).inMilliseconds > 500) {
          progress('Downloading ${source.item.name}: ${(bytes / 1048576).toStringAsFixed(1)} MiB');
          lastUpdate = DateTime.now();
        }
      });
      if ((await api.snapshot(plan.account, source.item.id)).revision != source.revision) throw const DriveApiException('Source changed while downloading. Source retained.');
      checkCancelled();
      progress('Uploading ${download.name}…');
      final id = await targetApi.uploadTransfer(destination, parent, download.name, download.mimeType, spool.length, (start, end) {
        checkCancelled();
        progress('Uploading ${download.name}: ${(start / 1048576).toStringAsFixed(1)} / ${(spool.length / 1048576).toStringAsFixed(1)} MiB');
        return spool.readRange(start, end);
      });
      final copy = await targetApi.snapshot(destination, id);
      if (copy.item.size != spool.length || !copy.item.parents.contains(parent) && parent != 'root') throw const DriveApiException('Destination metadata verification failed. Source retained.');
      progress('Verifying SHA-256 of ${download.name}…');
      final digest = await _hash(targetApi, destination, copy.item);
      if (digest != spool.digest || (await targetApi.snapshot(destination, id)).revision != copy.revision) throw const DriveApiException('Destination content verification failed. Source retained.');
      copies.add(VerifiedCopy(plan.account, source, destination, copy, digest));
    } finally { await spool.close(); }
  }

  Future<String> _hash(CloudDriveApi api, DriveAccount account, DriveItem item) async {
    final download = await api.openTransfer(account, item);
    var count = 0;
    final digest = await sha256.bind(download.stream.timeout(const Duration(seconds: 60)).map((chunk) {
      checkCancelled();
      count += chunk.length;
      if (count > fileLimit) throw const DriveApiException('Verification exceeded the transfer limit.');
      return chunk;
    })).first;
    if (count != item.size) throw const DriveApiException('Destination download was incomplete.');
    return digest.toString();
  }

  Future<void> cleanup(VerifiedCopy copy) async {
    checkCancelled();
    final sourceApi = provider(copy.sourceAccount);
    final destinationApi = provider(copy.destination);
    final current = await sourceApi.snapshot(copy.sourceAccount, copy.source.item.id);
    final destination = await destinationApi.snapshot(copy.destination, copy.copy.item.id);
    if (current.revision != copy.source.revision || destination.revision != copy.copy.revision) throw const DriveApiException('A source or destination changed after verification. Cleanup stopped.');
    await sourceApi.trashUnchanged(copy.sourceAccount, copy.source);
  }
}

class _Plan {
  const _Plan(this.account, this.snapshot, this.children);
  final DriveAccount account;
  final TransferSnapshot snapshot;
  final List<_Plan> children;
}
