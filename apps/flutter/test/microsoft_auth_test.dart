import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:farooqdrive/cloud_drive_api.dart';
import 'package:farooqdrive/microsoft_auth_desktop.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Exercise the real loopback callback; Microsoft HTTP calls remain MockClient
// requests. The default widget binding replaces even loopback HTTP with 400.
class AuthTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  AuthTestBinding();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  const id = '11111111-2222-3333-4444-555555555555';

  test('PKCE callback exchange refresh rotation restore and disconnect', () async {
    late Uri authorization;
    var refreshes = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'graph.microsoft.com') {
        return http.Response(jsonEncode({'id': 'user', 'mail': 'test@example.invalid'}), 200);
      }
      final form = Uri.splitQueryString(request.body);
      expect(form.containsKey('client_secret'), isFalse);
      if (form['grant_type'] == 'authorization_code') {
        expect(form['redirect_uri'], authorization.queryParameters['redirect_uri']);
        final hash = base64Url.encode(sha256.convert(utf8.encode(form['code_verifier']!)).bytes).replaceAll('=', '');
        expect(hash, authorization.queryParameters['code_challenge']);
        return http.Response(jsonEncode({'access_token': 'access', 'refresh_token': 'refresh1', 'expires_in': 0}), 200);
      }
      refreshes++;
      expect(form['refresh_token'], refreshes == 1 ? 'refresh1' : 'refresh2');
      return http.Response(jsonEncode({'access_token': 'renewed', 'refresh_token': 'refresh2', 'expires_in': 3600}), 200);
    });
    addTearDown(client.close);
    final auth = MicrosoftAccountAuthorizer(client: client, openBrowser: (uri) async {
      authorization = uri;
      expect(uri.queryParameters['prompt'], 'select_account');
      expect(uri.queryParameters['code_challenge_method'], 'S256');
      final callback = Uri.parse(uri.queryParameters['redirect_uri']!).replace(queryParameters: {
        'state': uri.queryParameters['state']!, 'code': 'test-code',
      });
      final response = await http.get(callback);
      expect(response.statusCode, 200);
      return true;
    });
    final account = (await auth.addAccount(id))!;
    expect(account.id, 'onedrive:user');
    expect(await auth.accessToken(account), 'renewed');
    final restoredAuth = MicrosoftAccountAuthorizer(client: client);
    final restored = await restoredAuth.restoreAccounts();
    expect(restored.single.refreshToken, 'refresh2');
    expect(await restoredAuth.accessToken(restored.single), 'renewed');
    await restoredAuth.forgetAccount(account.id);
    expect(await restoredAuth.restoreAccounts(), isEmpty);
  }, skip: !MicrosoftAccountAuthorizer.supported);

  test('wrong state cannot exchange an authorization code', () async {
    var exchanges = 0;
    final client = MockClient((request) async { exchanges++; return http.Response('{}', 400); });
    addTearDown(client.close);
    final auth = MicrosoftAccountAuthorizer(client: client,
      callbackTimeout: const Duration(milliseconds: 500), openBrowser: (uri) async {
        final callback = Uri.parse(uri.queryParameters['redirect_uri']!).replace(queryParameters: {
          'state': 'wrong-state', 'code': 'test-code',
        });
        expect((await http.get(callback)).statusCode, 400);
        return true;
      });
    await expectLater(auth.addAccount(id), throwsA(isA<DriveApiException>()));
    expect(exchanges, 0);
  }, skip: !MicrosoftAccountAuthorizer.supported);
}
