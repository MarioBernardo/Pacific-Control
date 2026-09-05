import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_provider.dart';
import '../features/auth/presentation/auth_loading_page.dart';
import '../features/auth/presentation/home_page.dart';
import '../features/auth/presentation/login_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isLogin = state.matchedLocation == '/login';

      if (authState.isRestoring) {
        return null;
      }
      if (!authState.isAuthenticated && !isLogin) {
        return '/login';
      }
      if (authState.isAuthenticated && isLogin) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) {
          return ref.read(authControllerProvider).isRestoring
              ? const AuthLoadingPage()
              : const LoginPage();
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          return ref.read(authControllerProvider).isRestoring
              ? const AuthLoadingPage()
              : const HomePage();
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
