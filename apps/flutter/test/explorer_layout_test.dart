import 'package:farooqdrive/drive_controller.dart';
import 'package:farooqdrive/explorer_widgets.dart';
import 'package:farooqdrive/main.dart';
import 'package:farooqdrive/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('eight views render and information moves into a red dialog', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = DriveController();
    addTearDown(controller.dispose);
    controller.accounts.add(DriveAccount(id: 'g', email: 'test@example.invalid', name: 'Account', accessToken: 'test'));
    controller.selectedAccountId = 'g';
    controller.paths['g'] = const [FolderCrumb('root', 'My Drive')];
    controller.files.add(const DriveItem(id: 'file', name: 'Example.txt', mimeType: 'text/plain',
      isFolder: false, accountId: 'g', accountEmail: 'test@example.invalid', size: 3));
    await tester.pumpWidget(MaterialApp(home: FileManagerPage(controller: controller)));
    await tester.pump();
    expect(explorerViewLabels.values, ['Extra large icons','Large icons','Medium icons','Small icons','List','Details','Tiles','Content']);
    final backY = tester.getCenter(find.byTooltip('Back')).dy;
    final uploadY = tester.getCenter(find.text('Upload')).dy;
    expect((backY - uploadY).abs(), lessThan(8));
    for (final mode in explorerViewLabels.keys) {
      controller.setLayout(mode);
      await tester.pump();
      expect(find.text('Example.txt'), findsWidgets);
      expect(tester.takeException(), isNull, reason: mode);
    }
    expect(find.textContaining('Cloud transfers use temporary'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('transfer-information')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cloud transfers use temporary'), findsOneWidget);
    final info = tester.widget<SelectableText>(find.byWidgetPredicate((widget) =>
      widget is SelectableText && (widget.data?.startsWith('Cloud transfers use temporary') ?? false)));
    expect(info.style?.color, Colors.red);
    expect(info.style?.fontSize, 11);
  });

  testWidgets('current folder blank area accepts internal drops', (tester) async {
    final controller = DriveController();
    addTearDown(controller.dispose);
    controller.accounts.add(DriveAccount(id: 'g', email: 'test@example.invalid', name: 'Account', accessToken: 'test'));
    controller.selectedAccountId = 'g';
    controller.paths['g'] = const [FolderCrumb('root', 'My Drive')];
    const item = DriveItem(id: 'file', name: 'Drag me', mimeType: 'text/plain',
      isFolder: false, accountId: 'g', accountEmail: 'test@example.invalid');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      CloudDragSource(controller: controller, item: item, child: const SizedBox(width: 180, height: 50, child: Text('Drag me'))),
      Expanded(child: CloudDropTarget(controller: controller, accountId: 'g',
        path: const [FolderCrumb('root','My Drive')], child: const SizedBox.expand(key: ValueKey('empty-folder')))),
    ]))));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Drag me')));
    await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('empty-folder'))));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Copy or move here?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.clipboard, isNull);
  });
  testWidgets('dark theme keeps all eight views usable and headers sort', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = DriveController();
    addTearDown(c.dispose);
    c.accounts.add(DriveAccount(id:'g',email:'test@example.invalid',name:'Account',accessToken:'test'));
    c.selectedAccountId = 'g';
    c.paths['g'] = const [FolderCrumb('root','My Drive')];
    c.files.add(const DriveItem(id:'a',name:'Example.txt',mimeType:'text/plain',isFolder:false,accountId:'g',accountEmail:'test@example.invalid',size:3));
    await tester.pumpWidget(MaterialApp(theme: ThemeData(brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark)),
      home: FileManagerPage(controller:c)));
    await tester.pump();
    expect(find.text('Version 21.1'), findsOneWidget);
    expect(find.textContaining('Test'), findsNothing);
    await tester.tap(find.text('Name ↑'));
    await tester.pump();
    expect(c.sortAscending,isFalse);
    await c.setViewMode(FileViewMode.files);
    await tester.pump();
    expect(find.text('Name ↓'),findsOneWidget);
    for (final mode in explorerViewLabels.keys) {
      c.setLayout(mode);
      await tester.pump();
      expect(find.text('Example.txt'),findsWidgets);
      expect(tester.takeException(),isNull,reason:mode);
    }
    expect(find.byTooltip('Switch light / dark mode'),findsOneWidget);
  });

}
