import 'google_drive_api.dart';
import 'models.dart';

/// Safe milestone-one mobile adapter.
///
/// Android/iOS must never fall through to the desktop OAuth flow, which uses a
/// loopback redirect and a client secret. Native OAuth is enabled only after
/// the package/bundle identity and signing certificate are registered.
class MobileGoogleAccountAuthorizer {
  static const buildClientId = '';
  static const clientIdLabel = 'Google Mobile OAuth';
  static const missingClientIdMessage =
      'Google sign-in will be enabled after mobile OAuth is registered.';

  Future<String> loadClientSecret() async => '';
  Future<void> saveClientSecret(String value) async {}

  Future<List<DriveAccount>> restoreAccounts(
    String savedClientId,
    String savedClientSecret,
  ) async => const [];

  Future<void> forgetAccount(String accountId) async {}

  Future<DriveAccount?> addAccount(
    String savedClientId,
    String savedClientSecret,
  ) async {
    throw const DriveApiException(
      'Android OAuth is not configured in this first private test build. '
      'No Google password or desktop client secret is accepted on mobile.',
    );
  }
}
