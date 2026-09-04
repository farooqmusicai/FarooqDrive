import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'google_drive_api.dart';
import 'models.dart';

class GoogleAccountAuthorizer {
  GoogleAccountAuthorizer({GoogleDriveApi? driveApi})
      : _driveApi = driveApi ?? GoogleDriveApi();

  static const clientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const scopes = <String>[
    'openid',
    'email',
    'profile',
    'https://www.googleapis.com/auth/drive',
  ];

  final GoogleDriveApi _driveApi;

  Future<DriveAccount?> addAccount() async {
    if (clientId.isEmpty) {
      throw const DriveApiException(
        'This build has no Google Web Client ID. Rebuild with GOOGLE_CLIENT_ID.',
      );
    }
    final signIn = GoogleSignIn(clientId: clientId, scopes: scopes);
    await signIn.signOut();
    final user = await signIn.signIn();
    if (user == null) return null;
    final auth = await user.authentication;
    if (auth.accessToken == null) {
      throw const DriveApiException('Google did not return an access token.');
    }
    final response = await http.get(
      Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
      headers: {'Authorization': 'Bearer ${auth.accessToken}'},
    );
    if (response.statusCode != 200) {
      throw DriveApiException(
        'Could not load the Google account (${response.statusCode}).',
      );
    }
    final profile = jsonDecode(response.body) as Map<String, dynamic>;
    final account = DriveAccount(
      id: profile['sub'] as String? ?? user.id,
      email: user.email,
      name: user.displayName ?? user.email,
      photoUrl: user.photoUrl,
      accessToken: auth.accessToken!,
    );
    return _driveApi.refreshQuota(account);
  }
}
