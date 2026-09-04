import 'package:farooqdrive/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the FarooqDrive workspace', (tester) async {
    await tester.pumpWidget(const FarooqDriveApp());
    expect(find.text('FarooqDrive'), findsOneWidget);
    expect(find.text('Add Google account'), findsOneWidget);
  });
}
