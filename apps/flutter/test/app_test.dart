import 'package:farooqdrive/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the FarooqDrive workspace', (tester) async {
    await tester.pumpWidget(const FarooqDriveApp());
    expect(find.text('All Drives'), findsWidgets);
    expect(find.text('Search all Drives'), findsOneWidget);
    expect(find.text('Files (0)'), findsOneWidget);
    expect(find.text('Folders (0)'), findsOneWidget);
    expect(find.text('Version 13'), findsOneWidget);
    expect(find.text('Design By'), findsOneWidget);
  });
}
