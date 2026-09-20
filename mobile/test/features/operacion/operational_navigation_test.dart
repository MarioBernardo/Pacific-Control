import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/operacion/models/device_session.dart';
import 'package:mobile/features/operacion/presentation/guardia_lista_page.dart';
import 'package:mobile/features/operacion/presentation/guardia_trabajo_page.dart';
import 'package:mobile/features/operacion/services/operacion_service.dart';
import 'package:mobile/features/operacion/services/native_capabilities.dart';
import 'package:mobile/features/operacion/providers/operacion_provider.dart';
import 'package:mobile/services/authenticated_api_client.dart';

const _device = DispositivoInfo(
  idDispositivo: 7,
  codigoDispositivo: 'BAVIERA-01',
  estado: 'ACTIVO',
  idPuesto: 1,
  puesto: PuestoInfo(
    idPuesto: 1,
    nombrePuesto: 'ED. BAVIERA',
    direccion: 'Quito',
    estado: 'ACTIVO',
  ),
);

const _guard = GuardiaDisponible(
  idEmpleado: 10,
  nombres: 'Diego Marcelo',
  apellidos: 'Tipantuña Taco',
  nombreCompleto: 'TIPANTUÑA TACO DIEGO MARCELO',
  cargo: 'GUARDIA',
  tipoAsignacion: 'FIJO',
  turnosDisponibles: [
    TurnoDisponible(idTurno: 1, tipoTurno: '12 HORAS'),
    TurnoDisponible(idTurno: 2, tipoTurno: '24 HORAS'),
  ],
  idPuesto: 1,
);

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

  GuardiaIdentificado? identifiedGuard;
  int logoutCalls = 0;
  int clearGuardCalls = 0;

  @override
  Future<SesionOperativa> getSession(int deviceId) async => SesionOperativa(
    dispositivo: _device,
    guardiaIdentificado: identifiedGuard,
    estado: identifiedGuard == null ? 'sin_identificar' : 'identificado',
  );

  @override
  Future<List<GuardiaDisponible>> getAvailableGuards(int deviceId) async =>
      const [_guard];

  @override
  Future<SesionOperativa> identifyGuard(
    int deviceId,
    int empleadoId,
    String tipoTurno,
  ) async {
    identifiedGuard = GuardiaIdentificado(
      idEmpleado: empleadoId,
      nombres: _guard.nombres,
      apellidos: _guard.apellidos,
      nombreCompleto: _guard.nombreCompleto,
      cargo: _guard.cargo,
      tipoAsignacion: _guard.tipoAsignacion,
      tipoTurno: tipoTurno,
      idTurno: tipoTurno == '12 HORAS' ? 1 : 2,
    );
    return getSession(deviceId);
  }

  @override
  Future<void> clearSession(int deviceId) async {
    clearGuardCalls++;
    identifiedGuard = null;
  }

  @override
  Future<void> logoutDevice(int deviceId) async {
    logoutCalls++;
  }
}

class _FakeNativeCapabilities implements NativeCapabilities {
  NativePermissionState cameraPermission = NativePermissionState.granted;
  String? photoPath = '/tmp/captured.jpg';
  Object? cameraError;
  int takePhotoCalls = 0;
  int settingsCalls = 0;

  @override
  Future<NativePermissionState> requestCameraPermission() async =>
      cameraPermission;
  @override
  Future<String?> takePhoto() async {
    takePhotoCalls++;
    if (cameraError != null) throw cameraError!;
    return photoPath;
  }

  @override
  Future<bool> openSettings() async {
    settingsCalls++;
    return true;
  }

  @override
  Future<LocationResult> currentLocation() async => const LocationResult(0, 0);
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
  @override
  Future<NativePermissionState> requestLocationPermission() async =>
      NativePermissionState.granted;
}

void main() {
  Future<_FakeOperacionService> render(
    WidgetTester tester, {
    GuardiaIdentificado? guard,
    _FakeNativeCapabilities? native,
  }) async {
    final service = _FakeOperacionService()..identifiedGuard = guard;
    final router = GoRouter(
      initialLocation: '/operacion/7',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('PORTADA')),
        ),
        GoRoute(
          path: '/operacion/:deviceId',
          builder: (_, _) => const GuardiaTrabajoPage(deviceId: 7),
        ),
        GoRoute(
          path: '/operacion/:deviceId/guardias',
          builder: (_, _) => const GuardiaListaPage(deviceId: 7),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          operacionServiceProvider.overrideWithValue(service),
          if (native != null)
            nativeCapabilitiesProvider.overrideWithValue(native),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets(
    'inicio operativo sin guardia navega y regresa sin cerrar dispositivo',
    (tester) async {
      final service = await render(tester);
      expect(find.text('ED. BAVIERA'), findsOneWidget);
      expect(find.text('BAVIERA-01'), findsOneWidget);
      expect(find.text('Ningún guardia identificado.'), findsOneWidget);

      await tester.tap(find.text('SELECCIONAR GUARDIA'));
      await tester.pumpAndSettle();
      expect(find.text('FIJOS'), findsOneWidget);

      await tester.tap(find.byTooltip('Volver al inicio operativo'));
      await tester.pumpAndSettle();
      expect(find.text('Ningún guardia identificado.'), findsOneWidget);
      expect(service.logoutCalls, 0);
    },
  );

  for (final shift in ['12 HORAS', '24 HORAS']) {
    testWidgets('seleccionar guardia conserva FIJO y turno $shift', (
      tester,
    ) async {
      final service = await render(tester);
      await tester.tap(find.text('SELECCIONAR GUARDIA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_guard.nombreCompleto));
      await tester.pumpAndSettle();
      await tester.tap(find.text(shift));
      await tester.tap(find.text('Identificar'));
      await tester.pumpAndSettle();

      expect(find.text(_guard.nombreCompleto), findsOneWidget);
      expect(find.text('FIJO'), findsWidgets);
      expect(find.text(shift), findsOneWidget);
      expect(service.logoutCalls, 0);
    });
  }

  testWidgets(
    'cambiar guardia limpia identificacion pero conserva dispositivo',
    (tester) async {
      const guard = GuardiaIdentificado(
        idEmpleado: 10,
        nombres: 'Diego',
        apellidos: 'Tipantuña',
        nombreCompleto: 'TIPANTUÑA TACO DIEGO MARCELO',
        cargo: 'GUARDIA',
        tipoAsignacion: 'FIJO',
        tipoTurno: '12 HORAS',
        idTurno: 1,
      );
      final service = await render(tester, guard: guard);
      await tester.tap(find.text('Cambiar guardia'));
      await tester.pumpAndSettle();

      expect(find.text('Seleccionar guardia'), findsOneWidget);
      expect(service.clearGuardCalls, 1);
      expect(service.logoutCalls, 0);
    },
  );

  testWidgets('cerrar dispositivo vuelve a portada', (tester) async {
    final service = await render(tester);
    await tester.tap(find.byTooltip('Cerrar sesión del dispositivo'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar sesión del dispositivo?'), findsOneWidget);
    expect(service.logoutCalls, 0);
    await tester.tap(find.text('CERRAR SESIÓN'));
    await tester.pumpAndSettle();
    expect(find.text('PORTADA'), findsOneWidget);
    expect(service.logoutCalls, 1);
  });

  testWidgets('inicio y atras de formularios conservan sesion operativa', (
    tester,
  ) async {
    const guard = GuardiaIdentificado(
      idEmpleado: 10,
      nombres: 'Diego',
      apellidos: 'Tipantuña',
      nombreCompleto: 'TIPANTUÑA TACO DIEGO MARCELO',
      cargo: 'GUARDIA',
      tipoAsignacion: 'FIJO',
      tipoTurno: '12 HORAS',
      idTurno: 1,
    );
    final service = await render(tester, guard: guard);

    expect(find.byTooltip('Inicio operativo'), findsOneWidget);
    await tester.tap(find.text('Reportar novedad'));
    await tester.pumpAndSettle();
    expect(find.text('Reportar novedad'), findsWidgets);
    await tester.tap(find.text('ATRÁS'));
    await tester.pumpAndSettle();
    expect(find.text(guard.nombreCompleto), findsOneWidget);

    await tester.tap(find.text('Registrar asistencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ATRÁS'));
    await tester.pumpAndSettle();
    expect(find.text(guard.nombreCompleto), findsOneWidget);
    expect(service.logoutCalls, 0);
    expect(service.clearGuardCalls, 0);
  });

  testWidgets('cancelar logout conserva dispositivo y guardia', (tester) async {
    const guard = GuardiaIdentificado(
      idEmpleado: 10,
      nombres: 'Diego',
      apellidos: 'Tipantuña',
      nombreCompleto: 'TIPANTUÑA TACO DIEGO MARCELO',
      cargo: 'GUARDIA',
      tipoAsignacion: 'FIJO',
      tipoTurno: '12 HORAS',
      idTurno: 1,
    );
    final service = await render(tester, guard: guard);
    await tester.tap(find.byTooltip('Cerrar sesión del dispositivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();
    expect(find.text(guard.nombreCompleto), findsOneWidget);
    expect(service.logoutCalls, 0);
    expect(service.clearGuardCalls, 0);
  });

  testWidgets('captura muestra preview y permite repetir y eliminar', (
    tester,
  ) async {
    const guard = GuardiaIdentificado(
      idEmpleado: 10,
      nombres: 'Diego',
      apellidos: 'Tipantuña',
      nombreCompleto: 'TIPANTUÑA TACO DIEGO MARCELO',
      cargo: 'GUARDIA',
      tipoAsignacion: 'FIJO',
      tipoTurno: '12 HORAS',
      idTurno: 1,
    );
    final native = _FakeNativeCapabilities();
    await render(tester, guard: guard, native: native);
    await tester.tap(find.text('Reportar novedad'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Puerta abierta');

    await tester.tap(find.text('TOMAR FOTOGRAFÍA'));
    await tester.pumpAndSettle();
    expect(find.text('Evidencia fotográfica'), findsOneWidget);
    await tester.tap(find.text('CONTINUAR'));
    await tester.pumpAndSettle();

    expect(find.text('USAR FOTO'), findsOneWidget);
    expect(find.text('REPETIR'), findsOneWidget);
    expect(find.text('ELIMINAR'), findsOneWidget);
    expect(find.text('Puerta abierta'), findsOneWidget);
    expect(native.takePhotoCalls, 1);

    await tester.tap(find.text('REPETIR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUAR'));
    await tester.pumpAndSettle();
    expect(native.takePhotoCalls, 2);

    await tester.tap(find.text('ELIMINAR'));
    await tester.pumpAndSettle();
    expect(find.text('TOMAR FOTOGRAFÍA'), findsOneWidget);
    expect(find.text('Puerta abierta'), findsOneWidget);
  });

  testWidgets('cancelacion o error conserva formulario usable sin foto', (
    tester,
  ) async {
    const guard = GuardiaIdentificado(
      idEmpleado: 10,
      nombres: 'Diego',
      apellidos: 'Tipantuña',
      nombreCompleto: 'TIPANTUÑA TACO DIEGO MARCELO',
      cargo: 'GUARDIA',
      tipoAsignacion: 'FIJO',
      tipoTurno: '12 HORAS',
      idTurno: 1,
    );
    final native = _FakeNativeCapabilities()..photoPath = null;
    await render(tester, guard: guard, native: native);
    await tester.tap(find.text('Reportar novedad'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Sin foto');
    await tester.tap(find.text('TOMAR FOTOGRAFÍA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUAR'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Captura cancelada'), findsOneWidget);
    expect(find.text('Sin foto'), findsOneWidget);
    expect(find.text('Reportar'), findsOneWidget);
    expect(find.text('TOMAR FOTOGRAFÍA'), findsOneWidget);
  });
}
