import 'dart:convert';
import 'package:farooqdrive/onedrive_api.dart';
import 'package:farooqdrive/google_drive_api.dart';
import 'package:farooqdrive/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final account = DriveAccount(id:'a',email:'a@example.invalid',name:'A',accessToken:'test');
  test('OneDrive scans hierarchy pages, removes tombstones and keeps last item version', () async {
    var calls = 0;
    final progress = <int>[];
    final client = MockClient((request) async {
      expect(request.url.path,contains('/root/delta'));
      calls++;
      return http.Response(jsonEncode(calls == 1 ? {
        'value': [
          {'id':'root','root':{},'folder':{}},
          {'id':'f','name':'Folder','folder':{}},
          {'id':'x','name':'old','file':{},'size':1,'parentReference':{'id':'f'}},
        ],
        '@odata.nextLink':'https://graph.microsoft.com/v1.0/me/drive/root/delta?page=2',
      } : {
        'value': [
          {'id':'x','name':'New.txt','file':{},'size':9,'parentReference':{'id':'f'}},
          {'id':'f','deleted':{}},
        ],
        '@odata.deltaLink':'https://graph.microsoft.com/v1.0/me/drive/root/delta?token=done',
      }),200);
    });
    addTearDown(client.close);
    final api=OneDriveApi(tokenResolver:(a,{bool force=false}) async=>'test',client:client);
    final items=await api.listAllFiles(account,onProgress:progress.add);
    expect(items.single.name,'New.txt');
    expect(items.single.size,9);
    expect(progress,[2,1]);
    expect(calls,2);
  });
  test('OneDrive does not publish a truncated scan', () async {
    final client=MockClient((_) async=>http.Response('{"value":[]}',200));
    addTearDown(client.close);
    final api=OneDriveApi(tokenResolver:(a,{bool force=false}) async=>'test',client:client);
    await expectLater(api.listAllFiles(account),throwsA(isA<DriveApiException>()));
  });
  test('Google continues through empty pages and reports progress', () async {
    var calls=0;
    final progress=<int>[];
    final client=MockClient((request) async {
      calls++;
      return http.Response(jsonEncode(calls==1?{'files':[],'nextPageToken':'next'}:{
        'files':[{'id':'x','name':'File','size':'5'}],
      }),200);
    });
    addTearDown(client.close);
    final items=await GoogleDriveApi(client:client).listAllFiles(account,onProgress:progress.add);
    expect(items.single.size,5);expect(progress,[0,1]);expect(calls,2);
  });
  test('Google repeated page tokens fail rather than loop forever', () async {
    var calls=0;
    final client=MockClient((_) async {calls++;return http.Response('{"files":[],"nextPageToken":"same"}',200);});
    addTearDown(client.close);
    await expectLater(GoogleDriveApi(client:client).listAllFiles(account),throwsA(isA<DriveApiException>()));
    expect(calls,2);
  });
}
