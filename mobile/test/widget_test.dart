import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('muestra la aplicación Pacific Control', (tester) async {
    await tester.pumpWidget(const PacificControlApp());

    expect(find.byType(PacificControlApp), findsOneWidget);
  });
}