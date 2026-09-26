import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'features/operacion/services/operacion_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: PacificControlApp()));
}

class PacificControlApp extends ConsumerStatefulWidget {
  const PacificControlApp({super.key});

  @override
  ConsumerState<PacificControlApp> createState() => _PacificControlAppState();
}

class _PacificControlAppState extends ConsumerState<PacificControlApp> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (results) {
        if (!results.contains(ConnectivityResult.none)) {
          unawaited(
            ref.read(operacionServiceProvider).syncPendingOperations(),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pacific Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
