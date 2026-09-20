import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/auth/auth_provider.dart';
import 'package:mobile/features/attendance/models/administrative_reports.dart';
import 'package:mobile/features/attendance/providers/administrative_reports_provider.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/auth/services/auth_session.dart';
import 'package:mobile/features/operacion/services/operacion_service.dart';
import 'package:mobile/main.dart';
import 'package:mobile/services/authenticated_api_client.dart';

class _NoSessionAuthService extends AuthService {
  _NoSessionAuthService({this.restoredSession});

  final AuthSession? restoredSession;

  @override
  Future<AuthSession?> restoreSession() async => restoredSession;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => _adminSession;

  @override
  Future<void> logout() async {}
}

class _NoSessionOperacionService extends OperacionService {
  _NoSessionOperacionService()
    : super(
        AuthenticatedApiClient(
          client: MockClient((_) async => http.Response('{}', 200)),
          baseUrl: 'http://localhost',
          accessToken: () => null,
          onUnauthorized: () async {},
        ),
      );

  @override
  Future<int?> restoreDeviceSession() async => null;

  @override
  Future<void> clearLocalSession() async {}
}

const _adminSession = AuthSession(
  accessToken: 'administrative.jwt.token',
  employee: AuthEmployee(
    id: 1,
    firstName: 'Admin',
    lastName: 'Pacific',
    email: 'admin@pacific-control.com',
    position: 'ADMINISTRADOR',
  ),
);

const _supervisorSession = AuthSession(
  accessToken: 'supervisor.jwt.token',
  employee: AuthEmployee(
    id: 2,
    firstName: 'Supervisor',
    lastName: 'Pacific',
    email: 'supervisor@pacific-control.com',
    position: 'SUPERVISOR',
  ),
);

const _dashboard = AdministrativeDashboard(
  guardsOnShift: 2,
  attendancesToday: 3,
  openIncidents: 1,
  staffedPositions: 1,
  personnel: [],
);

void main() {
  testWidgets('muestra la aplicacion Pacific Control', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_NoSessionAuthService()),
          operacionServiceProvider.overrideWithValue(
            _NoSessionOperacionService(),
          ),
          administrativeDashboardProvider.overrideWith(
            (ref) async => _dashboard,
          ),
        ],
        child: const PacificControlApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(PacificControlApp), findsOneWidget);
  });

  testWidgets('sesion administrativa restaurada entra a interfaz existente', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            _NoSessionAuthService(restoredSession: _adminSession),
          ),
          operacionServiceProvider.overrideWithValue(
            _NoSessionOperacionService(),
          ),
          administrativeDashboardProvider.overrideWith(
            (ref) async => _dashboard,
          ),
        ],
        child: const PacificControlApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hola, Admin'), findsOneWidget);
    expect(find.text('Guardias en turno: 2'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Empleados'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Empleados'), findsOneWidget);
    expect(find.text('Puestos'), findsOneWidget);
    expect(find.text('Dispositivos'), findsOneWidget);
    expect(find.text('Turnos'), findsOneWidget);
  });

  testWidgets('cuenta administrativa valida entra y logout vuelve a portada', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_NoSessionAuthService()),
          operacionServiceProvider.overrideWithValue(
            _NoSessionOperacionService(),
          ),
          administrativeDashboardProvider.overrideWith(
            (ref) async => _dashboard,
          ),
        ],
        child: const PacificControlApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('unified_username')),
      'admin@pacific-control.com',
    );
    await tester.enterText(find.byKey(const Key('unified_password')), 'secret');
    await tester.tap(find.text('INICIAR SESION'));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Admin'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('PACIFIC CONTROL'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
  });

  for (final session in [_adminSession, _supervisorSession]) {
    testWidgets('${session.employee.position} conserva inicio y regreso', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(
              _NoSessionAuthService(restoredSession: session),
            ),
            operacionServiceProvider.overrideWithValue(
              _NoSessionOperacionService(),
            ),
            administrativeDashboardProvider.overrideWith(
              (ref) async => _dashboard,
            ),
          ],
          child: const PacificControlApp(),
        ),
      );
      await tester.pumpAndSettle();
      final attendanceButton = find.widgetWithText(
        FilledButton,
        'Asistencias',
      );
      await tester.scrollUntilVisible(
        attendanceButton,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(attendanceButton);
      await tester.pumpAndSettle();
      await tester.tap(attendanceButton);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Atrás'), findsOneWidget);
      await tester.tap(find.byTooltip('Atrás'));
      await tester.pumpAndSettle();
      expect(find.text('PACIFIC CONTROL'), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
    });
  }
}
