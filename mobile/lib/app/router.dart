import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/home_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/services/auth_service.dart';
import '../features/auth/services/auth_session.dart';

class AppRouter {
  AppRouter(this.authService);

  final AuthService authService;

  AuthSession? _session;

  late final GoRouter router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = _session != null;
      final isLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLogin) {
        return '/login';
      }

      if (isLoggedIn && isLogin) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) {
          return LoginPage(
            authService: authService,
            onAuthenticated: (session) {
              _session = session;
              router.go('/home');
            },
          );
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final session = _session;

          if (session == null) {
            return const SizedBox.shrink();
          }

          return HomePage(
            session: session,
            onLogout: () async {
              await authService.logout();
              _session = null;

              if (context.mounted) {
                router.go('/login');
              }
            },
          );
        },
      ),
    ],
  );
}