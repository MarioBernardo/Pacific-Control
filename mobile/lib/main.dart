import 'package:flutter/material.dart';

import 'features/auth/presentation/home_page.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/services/auth_session.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const PacificControlApp());
}

class PacificControlApp extends StatelessWidget {
  const PacificControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pacific Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final AuthService _authService = AuthService();
  late Future<AuthSession?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _authService.restoreSession();
  }

  void _startSession(AuthSession session) {
    setState(() {
      _sessionFuture = Future.value(session);
    });
  }

  Future<void> _closeSession() async {
    await _authService.logout();
    if (!mounted) {
      return;
    }
    setState(() {
      _sessionFuture = Future.value();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthSession?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data;
        if (session == null) {
          return LoginPage(
            authService: _authService,
            onAuthenticated: _startSession,
          );
        }

        return HomePage(
          session: session,
          onLogout: _closeSession,
        );
      },
    );
  }
}
