// test/widget_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ez2_lotto/main.dart';

void main() {
  testWidgets('EZ2App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EZ2App());
    expect(find.text('EZ2 / 2D Lotto'), findsOneWidget);
  });
}
