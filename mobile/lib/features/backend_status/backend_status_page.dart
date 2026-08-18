import 'package:flutter/material.dart';

import '../../config/app_environment.dart';
import '../../services/backend_service.dart';

class BackendStatusPage extends StatefulWidget {
  const BackendStatusPage({super.key, this.service});

  final BackendService? service;

  @override
  State<BackendStatusPage> createState() => _BackendStatusPageState();
}

class _BackendStatusPageState extends State<BackendStatusPage> {
  late Future<Map<String, dynamic>> _statusFuture;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  void _loadStatus() {
    _statusFuture = (widget.service ?? BackendService()).getBackendStatus();
  }

  void _retry() {
    setState(_loadStatus);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Comprobando conexión con el backend...'),
            ],
          );
        }

        if (snapshot.hasError) {
          return Column(
            children: [
              const Icon(Icons.cloud_off, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              const Text('No se pudo conectar con el backend.'),
              const SizedBox(height: 8),
              Text(
                'URL: ${AppEnvironment.apiBaseUrl}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          );
        }

        final status = snapshot.requireData;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.cloud_done, color: Colors.green, size: 40),
                const SizedBox(height: 8),
                Text(
                  status['status']?.toString() ?? 'Backend disponible',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('Proyecto: ${status['project'] ?? 'No informado'}'),
                Text('Versión: ${status['version'] ?? 'No informada'}'),
              ],
            ),
          ),
        );
      },
    );
  }
}
