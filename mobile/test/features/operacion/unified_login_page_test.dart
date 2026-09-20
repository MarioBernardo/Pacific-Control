import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/auth/presentation/login_page.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/auth/services/auth_session.dart';
import 'package:mobile/features/operacion/models/device_session.dart';
import 'package:mobile/features/operacion/services/operacion_service.dart';
import 'package:mobile/services/authenticated_api_client.dart';

const _device = DispositivoInfo(
  idDispositivo: 7,
  codigoDispositivo: 'BAVIERA-01',
  estado: 'ACTIVO',
  idPuesto: 1,
);

class _FakeAuthService extends AuthService {
  String? submittedEmail;
  int logoutCalls = 0;

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    submittedEmail = email;
    return const AuthSession(
      accessToken: 'administrative.jwt.token',
      employee: AuthEmployee(
        id: 1,
        firstName: 'Admin',
        lastName: 'Pacific',
        email: 'admin@pacific-control.com',
        position: 'ADMINISTRADOR',
      ),
    );
  }

  @override
  Future<void> logout() async => logoutCalls++;
}

class _FakeOperacionService extends OperacionService {
  _FakeOperacionService({this.restoredDeviceId})
    : super(
        AuthenticatedApiClient(
          client: MockClient((_) async => http.Response('{}', 200)),
          baseUrl: 'http://localhost',
          accessToken: () => null,
          onUnauthorized: () async {},
        ),
      );

  final int? restoredDeviceId;
  String? submittedUsername;
  String? submittedPassword;

  @override
  Future<int?> restoreDeviceSession() async => restoredDeviceId;

  @override
  Future<DispositivoInfo> login(String username, String password) async {
    submittedUsername = username;
    submittedPassword = password;
    return _device;
  }

  @override
  Future<void> clearLocalSession() async {}
}

void main() {
  Future<(_FakeAuthService, _FakeOperacionService)> render(
    WidgetTester tester, {
    int? restoredDeviceId,
  }) async {
    final auth = _FakeAuthService();
    final operation = _FakeOperacionService(restoredDeviceId: restoredDeviceId);
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        GoRoute(
          path: '/operacion/:deviceId',
          builder: (_, _) => const Scaffold(body: Text('FLUJO OPERATIVO')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          operacionServiceProvider.overrideWithValue(operation),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return (auth, operation);
  }

  testWidgets('sin sesion muestra una unica portada institucional', (
    tester,
  ) async {
    await render(tester);
    expect(find.text('PACIFIC CONTROL'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('MODO OPERATIVO'), findsNothing);
  });

  testWidgets('campo usuario vacio es rechazado', (tester) async {
    await render(tester);
    await tester.enterText(find.byKey(const Key('unified_password')), 'secret');
    await tester.tap(find.text('INICIAR SESION'));
    await tester.pump();
    expect(find.text('Ingresa el usuario.'), findsOneWidget);
  });

  testWidgets('baviera aplica trim y entra directamente al flujo operativo', (
    tester,
  ) async {
    final fakes = await render(tester);
    await tester.enterText(
      find.byKey(const Key('unified_username')),
      '  baviera  ',
    );
    await tester.enterText(
      find.byKey(const Key('unified_password')),
      'BavieraOperativa2026!',
    );
    await tester.tap(find.text('INICIAR SESION'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa un correo valido.'), findsNothing);
    expect(find.text('Ingresa un correo válido.'), findsNothing);
    expect(fakes.$2.submittedUsername, 'baviera');
    expect(fakes.$2.submittedPassword, 'BavieraOperativa2026!');
    expect(fakes.$1.submittedEmail, isNull);
    expect(fakes.$1.logoutCalls, 1);
    expect(find.text('FLUJO OPERATIVO'), findsOneWidget);
  });

  testWidgets('sesion operativa restaurada no vuelve a pedir credenciales', (
    tester,
  ) async {
    await render(tester, restoredDeviceId: 7);
    expect(find.text('FLUJO OPERATIVO'), findsOneWidget);
    expect(find.text('Usuario'), findsNothing);
  });
}
