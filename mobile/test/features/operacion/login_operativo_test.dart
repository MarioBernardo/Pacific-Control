import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/operacion/models/device_session.dart';
import 'package:mobile/features/operacion/presentation/dispositivo_seleccion_page.dart';
import 'package:mobile/features/operacion/services/operacion_service.dart';
import 'package:mobile/services/authenticated_api_client.dart';

class _FakeOperacionService extends OperacionService {
  _FakeOperacionService()
    : super(
        AuthenticatedApiClient(
          client: MockClient((_) async => http.Response('{}', 200)),
          baseUrl: 'http://localhost',
          accessToken: () => null,
          onUnauthorized: () async {},
        ),
      );

  String? submittedUsername;
  String? submittedPassword;
  final _pendingLogin = Completer<DispositivoInfo>();

  @override
  Future<int?> restoreDeviceSession() async => null;

  @override
  Future<DispositivoInfo> login(String username, String password) {
    submittedUsername = username;
    submittedPassword = password;
    return _pendingLogin.future;
  }
}

void main() {
  Future<_FakeOperacionService> renderLogin(WidgetTester tester) async {
    final service = _FakeOperacionService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [operacionServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: DispositivoSeleccionPage()),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets('el login operativo real acepta baviera sin validar email', (
    tester,
  ) async {
    final service = await renderLogin(tester);

    await tester.enterText(
      find.byKey(const Key('operational_username')),
      '  baviera  ',
    );
    await tester.enterText(
      find.byKey(const Key('operational_password')),
      'BavieraOperativa2026!',
    );
    await tester.tap(find.text('INICIAR SESIÓN'));
    await tester.pump();

    expect(find.text('Ingresa un correo válido.'), findsNothing);
    expect(find.text('Ingresa un correo valido.'), findsNothing);
    expect(find.text('Ingresa el usuario.'), findsNothing);
    expect(service.submittedUsername, 'baviera');
    expect(service.submittedPassword, 'BavieraOperativa2026!');
  });

  testWidgets('el login operativo real rechaza usuario con solo espacios', (
    tester,
  ) async {
    final service = await renderLogin(tester);

    await tester.enterText(
      find.byKey(const Key('operational_username')),
      '   ',
    );
    await tester.enterText(
      find.byKey(const Key('operational_password')),
      'BavieraOperativa2026!',
    );
    await tester.tap(find.text('INICIAR SESIÓN'));
    await tester.pump();

    expect(find.text('Ingresa el usuario.'), findsOneWidget);
    expect(service.submittedUsername, isNull);
  });
}
