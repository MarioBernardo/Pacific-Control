import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../config/app_environment.dart';
import '../../services/authenticated_api_client.dart';
import 'services/auth_service.dart';
import 'services/auth_session.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final authenticatedApiClientProvider = Provider<AuthenticatedApiClient>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return AuthenticatedApiClient(
    client: client,
    baseUrl: AppEnvironment.apiBaseUrl,
    accessToken: () => ref.read(authControllerProvider).session?.accessToken,
    onUnauthorized: () => ref.read(authControllerProvider.notifier).logout(),
  );
});

enum AuthStatus { restoring, unauthenticated, authenticated }

class AuthState {
  const AuthState._({required this.status, this.session});

  const AuthState.restoring() : this._(status: AuthStatus.restoring);

  const AuthState.unauthenticated() : this._(status: AuthStatus.unauthenticated);

  const AuthState.authenticated(AuthSession session)
      : this._(status: AuthStatus.authenticated, session: session);

  final AuthStatus status;
  final AuthSession? session;

  bool get isRestoring => status == AuthStatus.restoring;
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future<void>.microtask(restoreSession);
    return const AuthState.restoring();
  }

  Future<void> restoreSession() async {
    try {
      final session = await ref.read(authServiceProvider).restoreSession();
      state = session == null
          ? const AuthState.unauthenticated()
          : AuthState.authenticated(session);
    } catch (error, stackTrace) {
      debugPrint('No fue posible restaurar la sesion: $error\n$stackTrace');
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> login({required String email, required String password}) async {
    final session = await ref.read(authServiceProvider).login(
          email: email,
          password: password,
        );
    state = AuthState.authenticated(session);
  }

  void setSession(AuthSession session) {
    state = AuthState.authenticated(session);
  }

  Future<void> logout() async {
    try {
      await ref.read(authServiceProvider).logout();
    } finally {
      state = const AuthState.unauthenticated();
    }
  }
}
