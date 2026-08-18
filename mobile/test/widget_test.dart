import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('shows the login page when there is no stored session',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PacificControlApp());
    await tester.pump();

    expect(find.text('PACIFIC CONTROL'), findsOneWidget);
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
  });
}
