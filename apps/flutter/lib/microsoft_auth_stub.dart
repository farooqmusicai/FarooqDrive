import 'cloud_drive_api.dart';
import 'models.dart';

class MicrosoftAccountAuthorizer {
  static const buildClientId = '';
  static const supported = false;
  final List<String> restoreWarnings = [];
  Future<List<DriveAccount>> restoreAccounts() async => [];
  Future<void> forgetAccount(String id) async {}
  Future<DriveAccount?> addAccount(String clientId) async =>
      throw const DriveApiException('OneDrive login is available on Windows first.');
  Future<String> accessToken(DriveAccount account, {bool force = false}) async =>
      throw const DriveApiException('OneDrive login is available on Windows first.');
}
