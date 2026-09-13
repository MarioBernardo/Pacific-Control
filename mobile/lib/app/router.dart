import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/attendance/presentation/asistencias_page.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/presentation/auth_loading_page.dart';
import '../features/auth/presentation/home_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/devices/presentation/dispositivos_page.dart';
import '../features/employees/presentation/empleados_page.dart';
import '../features/incidents/presentation/novedades_page.dart';
import '../features/operacion/presentation/dispositivo_info_page.dart';
import '../features/operacion/presentation/dispositivo_seleccion_page.dart';
import '../features/operacion/presentation/guardia_lista_page.dart';
import '../features/operacion/presentation/guardia_trabajo_page.dart';
import '../features/positions/presentation/puestos_page.dart';
import '../features/shifts/presentation/turnos_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isLogin = state.matchedLocation == '/login';

      if (authState.isRestoring) return null;
      if (!authState.isAuthenticated && !isLogin) return '/login';
      if (authState.isAuthenticated && isLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) =>
              ref.watch(authControllerProvider).isRestoring
              ? const AuthLoadingPage()
              : const LoginPage(),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) =>
              ref.watch(authControllerProvider).isRestoring
              ? const AuthLoadingPage()
              : const HomePage(),
        ),
      ),
      GoRoute(
        path: '/empleados',
        builder: (context, state) => const EmpleadosPage(),
      ),
      GoRoute(
        path: '/puestos',
        builder: (context, state) => const PuestosPage(),
      ),
      GoRoute(
        path: '/dispositivos',
        builder: (context, state) => const DispositivosPage(),
      ),
      GoRoute(path: '/turnos', builder: (context, state) => const TurnosPage()),
      GoRoute(
        path: '/asistencias',
        builder: (context, state) => const AsistenciasPage(),
      ),
      GoRoute(
        path: '/novedades',
        builder: (context, state) => const NovedadesPage(),
      ),
      // ── Operative flow ──────────────────────────────────────
      GoRoute(
        path: '/operacion',
        builder: (context, state) => const DispositivoSeleccionPage(),
      ),
      GoRoute(
        path: '/operacion/:deviceId',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['deviceId'] ?? '') ?? 0;
          return DispositivoInfoPage(deviceId: id);
        },
      ),
      GoRoute(
        path: '/operacion/:deviceId/guardias',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['deviceId'] ?? '') ?? 0;
          return GuardiaListaPage(deviceId: id);
        },
      ),
      GoRoute(
        path: '/operacion/:deviceId/trabajo',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['deviceId'] ?? '') ?? 0;
          return GuardiaTrabajoPage(deviceId: id);
        },
      ),
    ],
  );
});

class _AuthRouterRefreshNotifier extends ChangeNotifier {
  _AuthRouterRefreshNotifier(Ref ref) {
    _subscription = ref.listen<AuthState>(
      authControllerProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
