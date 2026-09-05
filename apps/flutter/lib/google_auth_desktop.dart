import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'google_drive_api.dart';
import 'models.dart';

class GoogleAccountAuthorizer {
  GoogleAccountAuthorizer({GoogleDriveApi? driveApi})
      : _driveApi = driveApi ?? GoogleDriveApi();

  static const buildClientId =
      String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
  static const clientIdLabel = 'Google Desktop Client ID';
  static const missingClientIdMessage =
      'Open Settings and add your Google Desktop Client ID first.';
  static const scopes = <String>[
    'openid', 'email', 'profile', 'https://www.googleapis.com/auth/drive',
  ];
  static const _storage = FlutterSecureStorage();
  static const _accountIndexKey = 'farooqdrive.desktop.accounts';

  final GoogleDriveApi _driveApi;

  Future<DriveAccount?> addAccount(String savedClientId) async {
    final clientId = _resolveClientId(savedClientId);
    final verifier = _randomUrlSafe(64);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final state = _randomUrlSafe(32);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://127.0.0.1:${server.port}';
    final authorizationUri = Uri.https(
      'accounts.google.com',
      '/o/oauth2/v2/auth',
      {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scopes.join(' '),
        'access_type': 'offline',
        'prompt': 'select_account consent',
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      },
    );
    if (!await launchUrl(authorizationUri, mode: LaunchMode.externalApplication)) {
      await server.close(force: true);
      throw const DriveApiException('Could not open the Google sign-in page.');
    }

    late HttpRequest request;
    try {
      request = await server.first.timeout(const Duration(minutes: 5));
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write('<!doctype html><title>FarooqDrive</title><h2>Google account connected.</h2><p>You may close this window and return to FarooqDrive.</p>');
      await request.response.close();
    } on TimeoutException {
      throw const DriveApiException('Google sign-in timed out. Please try again.');
    } finally {
      await server.close(force: true);
    }
    if (request.uri.queryParameters['state'] != state) {
      throw const DriveApiException('Google sign-in security check failed.');
    }
    final oauthError = request.uri.queryParameters['error'];
    if (oauthError != null) {
      if (oauthError == 'access_denied') return null;
      throw DriveApiException('Google sign-in failed: $oauthError');
    }
    final code = request.uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const DriveApiException('Google did not return an authorization code.');
    }
    final token = await _exchangeCode(
      clientId: clientId,
      code: code,
      verifier: verifier,
      redirectUri: redirectUri,
    );
    final account = await _accountFromToken(token, clientId: clientId);
    await _saveAccount(account);
    return _driveApi.refreshQuota(account);
  }

  Future<List<DriveAccount>> restoreAccounts(String savedClientId) async {
    final rawIndex = await _storage.read(key: _accountIndexKey);
    if (rawIndex == null || rawIndex.isEmpty) return const [];
    final ids = (jsonDecode(rawIndex) as List).cast<String>();
    final restored = <DriveAccount>[];
    for (final id in ids) {
      final raw = await _storage.read(key: _accountKey(id));
      if (raw == null) continue;
      try {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        final refreshToken = saved['refreshToken'] as String?;
        final clientId = (saved['clientId'] as String?)?.trim().isNotEmpty == true
            ? saved['clientId'] as String
            : _resolveClientId(savedClientId);
        if (refreshToken == null || refreshToken.isEmpty) continue;
        final token = await _refreshToken(clientId, refreshToken);
        final account = await _accountFromToken(
          token,
          clientId: clientId,
          fallbackRefreshToken: refreshToken,
        );
        await _saveAccount(account);
        restored.add(await _driveApi.refreshQuota(account));
      } catch (_) {
        // Keep other saved accounts usable if one token was revoked.
      }
    }
    return restored;
  }

  Future<void> forgetAccount(String accountId) async {
    await _storage.delete(key: _accountKey(accountId));
    final rawIndex = await _storage.read(key: _accountIndexKey);
    if (rawIndex == null) return;
    final ids = (jsonDecode(rawIndex) as List).cast<String>()..remove(accountId);
    await _storage.write(key: _accountIndexKey, value: jsonEncode(ids));
  }

  String _resolveClientId(String savedClientId) {
    final clientId = savedClientId.trim().isNotEmpty
        ? savedClientId.trim()
        : buildClientId;
    if (!clientId.endsWith('.apps.googleusercontent.com')) {
      throw const DriveApiException(missingClientIdMessage);
    }
    return clientId;
  }

  Future<Map<String, dynamic>> _exchangeCode({
    required String clientId,
    required String code,
    required String verifier,
    required String redirectUri,
  }) => _tokenRequest({
        'client_id': clientId,
        'code': code,
        'code_verifier': verifier,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
      });

  Future<Map<String, dynamic>> _refreshToken(
    String clientId,
    String refreshToken,
  ) => _tokenRequest({
        'client_id': clientId,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      });

  Future<Map<String, dynamic>> _tokenRequest(Map<String, String> body) async {
    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || decoded['access_token'] == null) {
      throw DriveApiException(
        decoded['error_description'] as String? ?? 'Google token request failed.',
      );
    }
    return decoded;
  }

  Future<DriveAccount> _accountFromToken(
    Map<String, dynamic> token, {
    required String clientId,
    String? fallbackRefreshToken,
  }) async {
    final accessToken = token['access_token'] as String;
    final response = await http.get(
      Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw DriveApiException(
        'Could not load the Google account (${response.statusCode}).',
      );
    }
    final profile = jsonDecode(response.body) as Map<String, dynamic>;
    final email = profile['email'] as String? ?? 'Google account';
    return DriveAccount(
      id: profile['sub'] as String? ?? email,
      email: email,
      name: profile['name'] as String? ?? email,
      photoUrl: profile['picture'] as String?,
      accessToken: accessToken,
      refreshToken: token['refresh_token'] as String? ?? fallbackRefreshToken,
      tokenExpiry: DateTime.now().add(
        Duration(seconds: (token['expires_in'] as num?)?.toInt() ?? 3600),
      ),
      oauthClientId: clientId,
    );
  }

  Future<void> _saveAccount(DriveAccount account) async {
    final refreshToken = account.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return;
    await _storage.write(
      key: _accountKey(account.id),
      value: jsonEncode({
        'id': account.id,
        'email': account.email,
        'name': account.name,
        'refreshToken': refreshToken,
        'clientId': account.oauthClientId,
      }),
    );
    final rawIndex = await _storage.read(key: _accountIndexKey);
    final ids = rawIndex == null
        ? <String>[]
        : (jsonDecode(rawIndex) as List).cast<String>();
    if (!ids.contains(account.id)) ids.add(account.id);
    await _storage.write(key: _accountIndexKey, value: jsonEncode(ids));
  }

  String _accountKey(String id) => 'farooqdrive.desktop.account.$id';

  String _randomUrlSafe(int byteCount) {
    final random = Random.secure();
    return base64Url
        .encode(List<int>.generate(byteCount, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }
}
