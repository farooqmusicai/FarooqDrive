import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'cloud_drive_api.dart';
import 'models.dart';

class MicrosoftAccountAuthorizer {
  MicrosoftAccountAuthorizer({http.Client? client,
    FlutterSecureStorage? storage, Future<bool> Function(Uri)? openBrowser,
    this.callbackTimeout = const Duration(minutes: 5),
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage(),
       _openBrowser = openBrowser ?? _launch;

  static const buildClientId = String.fromEnvironment('MICROSOFT_DESKTOP_CLIENT_ID');
  static bool get supported => Platform.isWindows;
  static const scopes = 'openid profile email offline_access User.Read Files.ReadWrite';
  static const _indexKey = 'farooqdrive.microsoft.windows.accounts';
  static String _key(String id) => 'farooqdrive.microsoft.windows.account.$id';
  static Future<bool> _launch(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
  final http.Client _client;
  final FlutterSecureStorage _storage;
  final Future<bool> Function(Uri) _openBrowser;
  final Duration callbackTimeout;
  final Map<String, DriveAccount> _sessions = {};
  final Map<String, Future<String>> _refreshing = {};
  final List<String> restoreWarnings = [];

  static String _random(int length) {
    final random = Random.secure();
    return base64Url.encode(List.generate(length, (_) => random.nextInt(256))).replaceAll('=', '');
  }

  Future<DriveAccount?> addAccount(String savedClientId) async {
    if (!supported) throw const DriveApiException('OneDrive login is available on Windows first.');
    final clientId = buildClientId.isNotEmpty ? buildClientId : savedClientId.trim();
    if (!RegExp(r'^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$').hasMatch(clientId)) {
      throw const DriveApiException('Configure a Microsoft Application (client) ID first.');
    }
    final verifier = _random(64);
    final state = _random(32);
    final challenge = base64Url.encode(sha256.convert(utf8.encode(verifier)).bytes).replaceAll('=', '');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirect = 'http://localhost:${server.port}';
    final result = Completer<Map<String, String>>();
    final subscription = server.listen((request) async {
      final params = request.uri.queryParameters;
      final valid = request.method == 'GET' && request.uri.path == '/' &&
          params['state'] == state;
      request.response
        ..statusCode = valid ? 200 : 400
        ..headers.contentType = ContentType.text
        ..headers.set('Cache-Control', 'no-store')
        ..write(valid ? 'Return to FarooqDrive to finish sign-in.' : 'Invalid sign-in callback.');
      await request.response.close();
      if (valid && !result.isCompleted) result.complete(params);
    });
    late Map<String, String> params;
    try {
      final uri = Uri.https('login.microsoftonline.com', '/common/oauth2/v2.0/authorize', {
        'client_id': clientId, 'response_type': 'code', 'response_mode': 'query',
        'redirect_uri': redirect, 'scope': scopes, 'state': state,
        'code_challenge': challenge, 'code_challenge_method': 'S256',
        'prompt': 'select_account',
      });
      if (!await _openBrowser(uri)) throw const DriveApiException('Could not open Microsoft sign-in.');
      params = await result.future.timeout(callbackTimeout);
    } on TimeoutException {
      throw const DriveApiException('Microsoft sign-in timed out. Please try again.');
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
    if (params['error'] == 'access_denied') {
      throw const DriveApiException('Microsoft sign-in was cancelled or consent was blocked by your organization.');
    }
    if (params['error'] != null || params['code'] == null) {
      throw const DriveApiException('Microsoft sign-in was not completed. Check app registration or organization consent policy.');
    }
    final token = await _token({
      'client_id': clientId, 'grant_type': 'authorization_code',
      'code': params['code']!, 'code_verifier': verifier,
      'redirect_uri': redirect, 'scope': scopes,
    });
    final response = await _client.get(Uri.https('graph.microsoft.com', '/v1.0/me', {
      r'$select': 'id,displayName,mail,userPrincipalName',
    }), headers: {'Authorization': 'Bearer ${token['access_token']}'}).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) throw const DriveApiException('Could not read Microsoft account profile.');
    final profile = jsonDecode(response.body) as Map<String, dynamic>;
    final id = profile['id'] as String?;
    if (id == null || id.isEmpty) throw const DriveApiException('Microsoft account identity is missing.');
    final email = profile['mail'] as String? ?? profile['userPrincipalName'] as String? ?? 'Microsoft account';
    final account = DriveAccount(id: 'onedrive:$id', email: email,
      name: profile['displayName'] as String? ?? email,
      provider: CloudProviderType.onedrive,
      accessToken: token['access_token'] as String,
      refreshToken: token['refresh_token'] as String?,
      tokenExpiry: _expiry(token), oauthClientId: clientId,
    );
    if (account.refreshToken == null) throw const DriveApiException('Microsoft did not grant offline access. Please sign in again.');
    await _save(account);
    _sessions[account.id] = account;
    return account;
  }

  static DateTime _expiry(Map<String, dynamic> token) => DateTime.now().add(
    Duration(seconds: (token['expires_in'] as num?)?.toInt() ?? 3600));

  Future<Map<String, dynamic>> _token(Map<String, String> body) async {
    final response = await _client.post(Uri.https('login.microsoftonline.com', '/common/oauth2/v2.0/token'),
      body: body).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw DriveApiException('Microsoft session could not be renewed or authorized (${response.statusCode}). Sign in again; work accounts may require administrator consent.', statusCode: response.statusCode);
    }
    final token = jsonDecode(response.body) as Map<String, dynamic>;
    if (token['access_token'] is! String) throw const DriveApiException('Microsoft returned no access token.');
    return token;
  }

  Future<String> accessToken(DriveAccount account, {bool force = false}) async {
    final current = _sessions[account.id] ?? account;
    if (!force && current.accessToken.isNotEmpty && current.tokenExpiry != null &&
        current.tokenExpiry!.isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
      return current.accessToken;
    }
    if (_refreshing.containsKey(account.id)) return _refreshing[account.id]!;
    final future = _refresh(current);
    _refreshing[account.id] = future;
    try { return await future; } finally { _refreshing.remove(account.id); }
  }

  Future<String> _refresh(DriveAccount current) async {
    if (current.refreshToken == null || current.oauthClientId == null) {
      throw const DriveApiException('Microsoft account needs sign-in again.');
    }
    final token = await _token({'client_id': current.oauthClientId!,
      'grant_type': 'refresh_token', 'refresh_token': current.refreshToken!, 'scope': scopes});
    final updated = current.copyWith(accessToken: token['access_token'] as String,
      refreshToken: token['refresh_token'] as String?, tokenExpiry: _expiry(token));
    await _save(updated);
    _sessions[updated.id] = updated;
    return updated.accessToken;
  }

  Future<List<DriveAccount>> restoreAccounts() async {
    restoreWarnings.clear();
    if (!supported) return [];
    final raw = await _storage.read(key: _indexKey);
    if (raw == null) return [];
    final ids = (jsonDecode(raw) as List).cast<String>();
    final accounts = <DriveAccount>[];
    for (final id in ids) {
      try {
        final value = await _storage.read(key: _key(id));
        if (value == null) continue;
        final data = jsonDecode(value) as Map<String, dynamic>;
        if (!id.startsWith('onedrive:') || data['id'] != id) continue;
        final account = DriveAccount(id: id, email: data['email'] as String,
          name: data['name'] as String, provider: CloudProviderType.onedrive,
          accessToken: '', refreshToken: data['refreshToken'] as String,
          oauthClientId: data['clientId'] as String);
        _sessions[id] = account;
        accounts.add(account);
      } catch (_) { restoreWarnings.add('A saved Microsoft account could not be restored. Sign in again.'); }
    }
    return accounts;
  }

  Future<void> _save(DriveAccount account) async {
    await _storage.write(key: _key(account.id), value: jsonEncode({
      'id': account.id, 'email': account.email, 'name': account.name,
      'refreshToken': account.refreshToken, 'clientId': account.oauthClientId,
    }));
    final raw = await _storage.read(key: _indexKey);
    final ids = raw == null ? <String>[] : (jsonDecode(raw) as List).cast<String>();
    if (!ids.contains(account.id)) ids.add(account.id);
    await _storage.write(key: _indexKey, value: jsonEncode(ids));
  }

  Future<void> forgetAccount(String id) async {
    final refreshing = _refreshing[id];
    if (refreshing != null) { try { await refreshing; } catch (_) {} }
    await _storage.delete(key: _key(id));
    _sessions.remove(id);
    final raw = await _storage.read(key: _indexKey);
    if (raw == null) return;
    final ids = (jsonDecode(raw) as List).cast<String>()..remove(id);
    await _storage.write(key: _indexKey, value: jsonEncode(ids));
  }
}
