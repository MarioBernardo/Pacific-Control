import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/authenticated_api_client.dart';
import '../../../theme/app_colors.dart';
import '../models/device_session.dart';
import '../providers/operacion_provider.dart';

/// Shows device + puesto info and lets the user proceed to guard selection.
class DispositivoInfoPage extends ConsumerWidget {
  const DispositivoInfoPage({super.key, required this.deviceId});

  final int deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(deviceSessionProvider(deviceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivo'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(deviceSessionProvider(deviceId).notifier)
                .reload(),
          ),
        ],
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          error: error,
          onRetry: () =>
              ref.read(deviceSessionProvider(deviceId).notifier).reload(),
        ),
        data: (session) => _SessionView(
          session: session,
          deviceId: deviceId,
          onContinue: () =>
              context.push('/operacion/$deviceId/guardias'),
          onClearGuard: () =>
              ref.read(deviceSessionProvider(deviceId).notifier).clearSession(),
        ),
      ),
    );
  }
}

class _SessionView extends StatelessWidget {
  const _SessionView({
    required this.session,
    required this.deviceId,
    required this.onContinue,
    required this.onClearGuard,
  });

  final SesionOperativa session;
  final int deviceId;
  final VoidCallback onContinue;
  final VoidCallback onClearGuard;

  @override
  Widget build(BuildContext context) {
    final d = session.dispositivo;
    final puesto = d.puesto;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // --- Device card ---
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.darkBlue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.phone_android, color: AppColors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Dispositivo',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                d.codigoDispositivo,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (d.modelo != null) ...[
                const SizedBox(height: 4),
                Text(
                  d.modelo!,
                  style: const TextStyle(color: AppColors.lightBlueText),
                ),
              ],
              const SizedBox(height: 8),
              _StatusChip(estado: d.estado),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Puesto card ---
        if (puesto != null)
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.location_on,
                color: AppColors.darkBlue,
              ),
              title: Text(
                puesto.nombrePuesto,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(puesto.direccion),
            ),
          ),
        const SizedBox(height: 16),

        // --- Current guard (if any) ---
        if (session.identificado) ...[
          Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: const Icon(
                Icons.verified_user,
                color: Colors.green,
              ),
              title: Text(
                session.guardiaIdentificado!.nombreCompleto,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                session.guardiaIdentificado!.tipoAsignacion,
              ),
              trailing: TextButton(
                onPressed: onClearGuard,
                child: const Text('Cambiar'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              // Navigate to work screen with identified guard
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _OperationRedirect(deviceId: deviceId),
                ),
              );
            },
            icon: const Icon(Icons.work),
            label: const Text('Continuar operación'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Cambiar guardia'),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.people),
            label: const Text('Seleccionar guardia'),
          ),
        ],
      ],
    );
  }
}

class _OperationRedirect extends StatelessWidget {
  const _OperationRedirect({required this.deviceId});
  final int deviceId;

  @override
  Widget build(BuildContext context) {
    // Navigate using go_router to the work page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).pop();
        context.push('/operacion/$deviceId/trabajo');
      }
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.estado});
  final String estado;

  @override
  Widget build(BuildContext context) {
    final active = estado.toLowerCase() == 'activo';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? Colors.green.shade700 : Colors.red.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        estado.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
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
        : 'No se pudo cargar la información del dispositivo.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
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
