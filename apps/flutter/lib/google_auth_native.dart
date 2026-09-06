import 'dart:io';

import 'google_auth_desktop.dart';
import 'google_auth_mobile.dart';
import 'google_drive_api.dart';
import 'models.dart';

/// Routes native authentication without treating Android/iOS as desktop.
class GoogleAccountAuthorizer {
  GoogleAccountAuthorizer({GoogleDriveApi? driveApi})
    : _desktop = DesktopGoogleAccountAuthorizer(driveApi: driveApi),
      _mobile = MobileGoogleAccountAuthorizer();

  final DesktopGoogleAccountAuthorizer _desktop;
  final MobileGoogleAccountAuthorizer _mobile;

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  static String get buildClientId => _isMobile
      ? MobileGoogleAccountAuthorizer.buildClientId
      : DesktopGoogleAccountAuthorizer.buildClientId;
  static bool get usesPlatformCredentials => _isMobile;
  static String get clientIdLabel => _isMobile
      ? MobileGoogleAccountAuthorizer.clientIdLabel
      : DesktopGoogleAccountAuthorizer.clientIdLabel;
  static bool get requiresClientSecret =>
      !_isMobile && DesktopGoogleAccountAuthorizer.requiresClientSecret;
  static String get missingClientIdMessage => _isMobile
      ? MobileGoogleAccountAuthorizer.missingClientIdMessage
      : DesktopGoogleAccountAuthorizer.missingClientIdMessage;

  Future<String> loadClientSecret() =>
      _isMobile ? _mobile.loadClientSecret() : _desktop.loadClientSecret();

  Future<void> saveClientSecret(String value) => _isMobile
      ? _mobile.saveClientSecret(value)
      : _desktop.saveClientSecret(value);

  Future<DriveAccount?> addAccount(
    String savedClientId,
    String savedClientSecret,
  ) => _isMobile
      ? _mobile.addAccount(savedClientId, savedClientSecret)
      : _desktop.addAccount(savedClientId, savedClientSecret);

  Future<List<DriveAccount>> restoreAccounts(
    String savedClientId,
    String savedClientSecret,
  ) => _isMobile
      ? _mobile.restoreAccounts(savedClientId, savedClientSecret)
      : _desktop.restoreAccounts(savedClientId, savedClientSecret);

  Future<void> forgetAccount(String accountId) => _isMobile
      ? _mobile.forgetAccount(accountId)
      : _desktop.forgetAccount(accountId);
}
