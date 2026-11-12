import 'package:flutter_test/flutter_test.dart';
import 'package:minerba_mobile/main.dart';

void main() {
  testWidgets('MinerbaApp initial render test', (WidgetTester tester) async {
    await tester.pumpWidget(const MinerbaApp());
    expect(find.text('KONSERVASI MOBILE'), findsOneWidget);
  });
}
