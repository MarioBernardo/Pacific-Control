import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/agent/presentation/agent_page.dart';
import 'package:mobile/features/agent/providers/agent_provider.dart';
import 'package:mobile/features/agent/services/agent_service.dart';
import 'package:mobile/services/authenticated_api_client.dart';

AgentService serviceFor(Future<http.Response> Function(http.Request) handler) =>
    AgentService(AuthenticatedApiClient(
      client: MockClient(handler),
      baseUrl: 'http://localhost',
      accessToken: () => 'jwt',
      onUnauthorized: () async {},
    ));

Widget appWith(AgentService service) => ProviderScope(
  overrides: [agentServiceProvider.overrideWithValue(service)],
  child: const MaterialApp(home: AgentPage()),
);

void main() {
  test('cliente envia pregunta y transforma respuesta estructurada', () async {
    final service = serviceFor((request) async {
      expect(request.url.path, '/agente/consultar');
      expect(request.headers['authorization'], 'Bearer jwt');
      expect(request.body, contains('Resumen del día'));
      return http.Response(
        '{"data":{"respuesta":"Dos guardias en turno.","datos":{"dashboard":{"guardias_en_turno":2}},"fuentes_internas":["reportes.dashboard"],"generado_por_ia":true}}',
        200,
      );
    });
    final response = await service.consult(' Resumen del día ');
    expect(response.answer, 'Dos guardias en turno.');
    expect(response.generatedByAi, isTrue);
  });

  testWidgets('pantalla muestra loading y respuesta', (tester) async {
    final completer = Completer<http.Response>();
    await tester.pumpWidget(appWith(serviceFor((_) => completer.future)));
    await tester.enterText(find.byType(TextField), 'Resumen del día');
    await tester.tap(find.text('Consultar'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(http.Response(
      '{"data":{"respuesta":"Operación estable.","datos":{},"fuentes_internas":["reportes.dashboard"],"generado_por_ia":true}}', 200));
    await tester.pumpAndSettle();
    expect(find.text('Operación estable.'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final newQuery = find.widgetWithText(OutlinedButton, 'Nueva consulta');
    expect(newQuery, findsOneWidget);
  });

  testWidgets('pantalla muestra error seguro del backend', (tester) async {
    await tester.pumpWidget(appWith(serviceFor((_) async => http.Response('{"error":"El asistente no está disponible temporalmente."}', 503))));
    await tester.enterText(find.byType(TextField), 'Resumen');
    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();
    expect(find.text('El asistente no está disponible temporalmente.'), findsOneWidget);
  });

  testWidgets('pantalla rechaza pregunta vacia sin llamar API', (tester) async {
    var called = false;
    await tester.pumpWidget(appWith(serviceFor((_) async { called = true; return http.Response('{}', 200); })));
    await tester.tap(find.text('Consultar'));
    await tester.pump();
    expect(find.text('Escribe una pregunta antes de consultar.'), findsOneWidget);
    expect(called, isFalse);
  });
}
