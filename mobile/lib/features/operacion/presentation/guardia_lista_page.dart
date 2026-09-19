import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/authenticated_api_client.dart';
import '../../../theme/app_colors.dart';
import '../models/device_session.dart';
import '../providers/operacion_provider.dart';
import 'turno_selector.dart';

/// Shows the list of available guards for the device's puesto.
class GuardiaListaPage extends ConsumerWidget {
  const GuardiaListaPage({super.key, required this.deviceId});

  final int deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guardsAsync = ref.watch(deviceGuardsProvider(deviceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar guardia'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(deviceGuardsProvider(deviceId)),
          ),
        ],
      ),
      body: guardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(deviceGuardsProvider(deviceId)),
        ),
        data: (guards) {
          if (guards.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No hay guardias asignados a este puesto.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final fijos = guards.where((g) => g.esFijo).toList();
          final sacaFrancos = guards.where((g) => !g.esFijo).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (fijos.isNotEmpty) ...[
                _SectionHeader(
                  label: 'FIJOS',
                  icon: Icons.shield,
                  color: AppColors.darkBlue,
                ),
                const SizedBox(height: 8),
                ...fijos.map(
                  (g) => _GuardiaCard(
                    guardia: g,
                    onTap: () => _confirm(context, ref, g),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (sacaFrancos.isNotEmpty) ...[
                _SectionHeader(
                  label: 'SACA FRANCOS',
                  icon: Icons.swap_horiz,
                  color: AppColors.orange,
                ),
                const SizedBox(height: 8),
                ...sacaFrancos.map(
                  (g) => _GuardiaCard(
                    guardia: g,
                    onTap: () => _confirm(context, ref, g),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    GuardiaDisponible guardia,
  ) async {
    final tipoTurno = await showDialog<String>(
      context: context,
      builder: (_) => _ConfirmDialog(guardia: guardia),
    );
    if (tipoTurno == null || !context.mounted) return;

    try {
      await ref
          .read(deviceSessionProvider(deviceId).notifier)
          .identifyGuard(guardia.idEmpleado, tipoTurno);
      if (context.mounted) {
        context.go('/operacion/$deviceId/trabajo');
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _GuardiaCard extends StatelessWidget {
  const _GuardiaCard({required this.guardia, required this.onTap});

  final GuardiaDisponible guardia;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esFijo = guardia.esFijo;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              esFijo ? AppColors.orangeSurface : Colors.blue.shade50,
          child: Icon(
            esFijo ? Icons.shield : Icons.swap_horiz,
            color: esFijo ? AppColors.darkBlue : AppColors.orange,
          ),
        ),
        title: Text(
          guardia.nombreCompleto,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Align(
          alignment: Alignment.centerLeft,
          child: _AsignacionBadge(tipo: guardia.tipoAsignacion),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _AsignacionBadge extends StatelessWidget {
  const _AsignacionBadge({required this.tipo});
  final String tipo;

  @override
  Widget build(BuildContext context) {
    final esFijo = tipo.toUpperCase() == 'FIJO';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: esFijo ? AppColors.darkBlue : AppColors.orange,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        esFijo ? 'FIJO' : 'SACA FRANCO',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.guardia});
  final GuardiaDisponible guardia;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  String? _tipoTurno;
  GuardiaDisponible get guardia => widget.guardia;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar identidad'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person, size: 56, color: AppColors.darkBlue),
          const SizedBox(height: 12),
          Text(
            '¿Eres ${guardia.nombreCompleto}?',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          _AsignacionBadge(tipo: guardia.tipoAsignacion),
          const SizedBox(height: 20),
          TurnoSelector(
            opciones: guardia.turnosDisponibles
                .map((turno) => turno.tipoTurno)
                .toList(),
            seleccion: _tipoTurno,
            onChanged: (value) => setState(() => _tipoTurno = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _tipoTurno == null
              ? null
              : () => Navigator.of(context).pop(_tipoTurno),
          child: const Text('Identificar'),
        ),
      ],
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
        : 'No se pudieron cargar los guardias.';
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
