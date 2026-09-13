import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/authenticated_api_client.dart';
import '../../../theme/app_colors.dart';
import '../models/device_session.dart';
import '../providers/operacion_provider.dart';

/// Lists available devices so the user can select one to operate.
class DispositivoSeleccionPage extends ConsumerWidget {
  const DispositivoSeleccionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispositivos = ref.watch(dispositivosInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar dispositivo'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dispositivosInfoProvider),
          ),
        ],
      ),
      body: dispositivos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(dispositivosInfoProvider),
        ),
        data: (items) {
          final activos = items.where((d) => d.estado == 'activo').toList();
          if (activos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No hay dispositivos activos disponibles.'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: activos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final d = activos[index];
              return _DispositivoCard(
                dispositivo: d,
                onTap: () => context.push(
                  '/operacion/${d.idDispositivo}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DispositivoCard extends StatelessWidget {
  const _DispositivoCard({required this.dispositivo, required this.onTap});

  final DispositivoInfo dispositivo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: AppColors.orangeSurface,
          child: const Icon(Icons.phone_android, color: AppColors.darkBlue),
        ),
        title: Text(
          dispositivo.codigoDispositivo,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          dispositivo.puesto?.nombrePuesto ?? 'Puesto #${dispositivo.idPuesto}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : 'No se pudieron cargar los dispositivos.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
