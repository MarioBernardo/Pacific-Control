import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/operacion/presentation/turno_selector.dart';

void main() {
  testWidgets('requires an explicit 12 or 24 hour selection', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TurnoSelector(
              opciones: const ['12 HORAS', '24 HORAS'],
              seleccion: selected,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    expect(find.text('12 HORAS'), findsOneWidget);
    expect(find.text('24 HORAS'), findsOneWidget);
    expect(find.text('MIXTO'), findsNothing);
    expect(find.text('Seleccione el tipo de turno.'), findsOneWidget);

    await tester.tap(find.text('12 HORAS'));
    await tester.pump();
    expect(selected, '12 HORAS');
    expect(find.text('Seleccione el tipo de turno.'), findsNothing);

    await tester.tap(find.text('24 HORAS'));
    await tester.pump();
    expect(selected, '24 HORAS');
  });
}
