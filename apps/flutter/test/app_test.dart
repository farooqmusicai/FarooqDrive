import 'package:farooqdrive/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the FarooqDrive workspace', (tester) async {
    await tester.pumpWidget(const FarooqDriveApp());
    expect(find.text('All Drives'), findsOneWidget);
    expect(find.text('Search this folder'), findsOneWidget);
  });
}
