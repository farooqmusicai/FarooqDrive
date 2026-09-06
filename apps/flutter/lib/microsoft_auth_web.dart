import 'dart:convert';
import 'dart:js_interop';
import 'cloud_drive_api.dart';
import 'models.dart';

@JS('fdMicrosoftLogin')
external JSPromise<JSString> _login(JSString clientId);
@JS('fdMicrosoftToken')
external JSPromise<JSString> _token(JSString id, JSBoolean force);
@JS('fdMicrosoftForget')
external JSPromise<JSString> _forget(JSString id);

class MicrosoftAccountAuthorizer {
  static const buildClientId = String.fromEnvironment('MICROSOFT_WEB_CLIENT_ID');
  static const supported = true;
  final List<String> restoreWarnings = [];
  Future<List<DriveAccount>> restoreAccounts() async => [];
  Future<Map<String,dynamic>> _result(JSPromise<JSString> promise) async {
    try {
      final data=jsonDecode((await promise.toDart).toDart) as Map<String,dynamic>;
      if(data['error'] is String) throw DriveApiException(data['error'] as String);
      return data;
    } on DriveApiException { rethrow; }
    catch (_) { throw const DriveApiException('Microsoft browser sign-in unavailable. Reload the page and allow popups.'); }
  }
  Future<DriveAccount?> addAccount(String clientId) async {
    final id=buildClientId.isNotEmpty?buildClientId:clientId;
    final data=await _result(_login(id.toJS));
    return DriveAccount(id:data['id'] as String,email:data['email'] as String,name:data['name'] as String,
      accessToken:data['token'] as String,provider:CloudProviderType.onedrive);
  }
  Future<String> accessToken(DriveAccount account,{bool force=false}) async =>
    (await _result(_token(account.id.toJS,force.toJS)))['token'] as String;
  Future<void> forgetAccount(String id) async { await _forget(id.toJS).toDart; }
}
