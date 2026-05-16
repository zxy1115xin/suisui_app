import 'package:flutter_test/flutter_test.dart';
import 'package:suisui_app/main.dart';

void main() {
  testWidgets('SuiSui app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SuiSuiApp());
    expect(find.text('日历'), findsOneWidget);
  });
}
