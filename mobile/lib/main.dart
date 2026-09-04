import 'package:flutter/material.dart';

import 'app/router.dart';
import 'features/auth/services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const PacificControlApp());
}

class PacificControlApp extends StatefulWidget {
  const PacificControlApp({super.key});

  @override
  State<PacificControlApp> createState() => _PacificControlAppState();
}

class _PacificControlAppState extends State<PacificControlApp> {
  final AuthService _authService = AuthService();
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(_authService);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pacific Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _appRouter.router,
    );
  }
}