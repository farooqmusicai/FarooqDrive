import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

import 'storage_migration.dart';

class AppStorage {
  static String? _root;
  static String get root =>
      _root ?? '${Directory.systemTemp.path}\\FarooqDrive';
  static String get cache => '$root\\Cache';
}

String? currentPackageFamilyName() {
  final getFamily = DynamicLibrary.open('kernel32.dll').lookupFunction<
      Int32 Function(Pointer<Uint32>, Pointer<Utf16>),
      int Function(
          Pointer<Uint32>, Pointer<Utf16>)>('GetCurrentPackageFamilyName');
  final length = calloc<Uint32>();
  Pointer<Utf16>? buffer;
  try {
    final status = getFamily(length, nullptr);
    if (status == 15700) return null; // APPMODEL_ERROR_NO_PACKAGE
    if (status != 122 || length.value == 0 || length.value > 1024) {
      throw StateError('Cannot determine Windows package identity ($status).');
    }
    buffer = calloc<Uint16>(length.value).cast<Utf16>();
    final result = getFamily(length, buffer);
    if (result != 0) {
      throw StateError('Cannot read package identity ($result).');
    }
    return buffer.toDartString();
  } finally {
    if (buffer != null) calloc.free(buffer);
    calloc.free(length);
  }
}

class AppPathProvider extends PathProviderWindows {
  AppPathProvider(this.root);
  final String root;
  Future<String> _directory(String value) async =>
      (await Directory(value).create(recursive: true)).path;
  @override
  Future<String?> getApplicationSupportPath() => _directory(root);
  @override
  Future<String?> getApplicationCachePath() => _directory('$root\\Cache');
  @override
  Future<String?> getTemporaryPath() => _directory('$root\\Cache');
}

Future<void> initializeAppStorage() async {
  if (!Platform.isWindows) return;
  final local = Platform.environment['LOCALAPPDATA'];
  if (local == null || local.isEmpty) {
    throw StateError('Windows app data is unavailable.');
  }
  final family = currentPackageFamilyName();
  final root = family == null
      ? '$local\\FarooqDrive\\UserData'
      : '$local\\Packages\\$family\\LocalState\\FarooqDrive';
  AppStorage._root = root;
  final provider = AppPathProvider(root);
  await provider.getApplicationSupportPath();
  final legacyRoots = <Directory>[
    if (family != null)
      Directory(
          '$local\\Packages\\$family\\LocalCache\\Roaming\\com.example\\farooqdrive'),
    if ((family == null || family == 'MohammadFarooq.FarooqDrive_k4xyx05gnhd8w') && Platform.environment['APPDATA'] != null)
      Directory('${Platform.environment['APPDATA']}\\com.example\\farooqdrive'),
  ];
  await migrateLegacyStorage(Directory(root), legacyRoots);
  PathProviderPlatform.instance = provider;
  SharedPreferencesStorePlatform.instance = SharedPreferencesWindows()
    // The plugin constructs its own provider; route that instance to the same
    // uninstall-scoped directory used by encrypted tokens.
    // ignore: invalid_use_of_visible_for_testing_member
    ..pathProvider = provider;
}
