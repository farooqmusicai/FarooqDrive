import 'package:farooqdrive/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the FarooqDrive workspace', (tester) async {
    await tester.pumpWidget(const FarooqDriveApp());
    expect(find.text('All Drives'), findsWidgets);
    expect(find.text('Search all Drives'), findsOneWidget);
    expect(find.text('All (0)'), findsOneWidget);
    expect(find.text('Files (0)'), findsOneWidget);
    expect(find.text('Folders (0)'), findsOneWidget);
  });

  testWidgets('remains usable at a compact desktop width', (tester) async {
    tester.view.physicalSize = const Size(760, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FarooqDriveApp());
    await tester.pump();

    expect(find.text('Search all Drives'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
