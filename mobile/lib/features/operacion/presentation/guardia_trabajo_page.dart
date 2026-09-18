import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/authenticated_api_client.dart';
import '../../../theme/app_colors.dart';
import '../models/device_session.dart';
import '../providers/operacion_provider.dart';
import '../services/operacion_service.dart';

/// Main operative screen shown after a guard identifies themselves.
class GuardiaTrabajoPage extends ConsumerWidget {
  const GuardiaTrabajoPage({super.key, required this.deviceId});

  final int deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(deviceSessionProvider(deviceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operación'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(deviceSessionProvider(deviceId).notifier).reload(),
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
        data: (session) {
          if (!session.identificado) {
            // Guard was cleared — send back to guard list
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go('/operacion/$deviceId/guardias');
              }
            });
            return const Center(child: CircularProgressIndicator());
          }
          return _WorkView(session: session, deviceId: deviceId);
        },
      ),
    );
  }
}

class _WorkView extends StatelessWidget {
  const _WorkView({required this.session, required this.deviceId});

  final SesionOperativa session;
  final int deviceId;

  @override
  Widget build(BuildContext context) {
    final guardia = session.guardiaIdentificado!;
    final puesto = session.dispositivo.puesto;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Guard info card
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
                  Icon(Icons.verified_user, color: AppColors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Guardia identificado',
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
                guardia.nombreCompleto,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _AsignacionBadge(tipo: guardia.tipoAsignacion),
                  if (guardia.tipoTurno != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        guardia.tipoTurno!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Puesto info
        if (puesto != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on, color: AppColors.darkBlue),
              title: Text(puesto.nombrePuesto),
              subtitle: Text(puesto.direccion),
            ),
          ),
        const SizedBox(height: 24),

        // Action buttons
        Text('Acciones', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),

        FilledButton.icon(
          onPressed: () => _registrarAsistencia(context, session),
          icon: const Icon(Icons.fact_check),
          label: const Text('Registrar asistencia'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _reportarNovedad(context, session),
          icon: const Icon(Icons.add_alert),
          label: const Text('Reportar novedad'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _cambiarGuardia(context),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Cambiar guardia'),
        ),
      ],
    );
  }

  Future<void> _registrarAsistencia(
    BuildContext context,
    SesionOperativa session,
  ) async {
    final guardia = session.guardiaIdentificado!;
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _AsistenciaDialog(guardia: guardia, dispositivo: session.dispositivo),
    );
  }

  Future<void> _reportarNovedad(
    BuildContext context,
    SesionOperativa session,
  ) async {
    final guardia = session.guardiaIdentificado!;
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _NovedadDialog(guardia: guardia, dispositivo: session.dispositivo),
    );
  }

  void _cambiarGuardia(BuildContext context) {
    context.go('/operacion/$deviceId/guardias');
  }
}

// -----------------------------------------------------------------------
// Attendance registration dialog
// -----------------------------------------------------------------------

class _AsistenciaDialog extends ConsumerStatefulWidget {
  const _AsistenciaDialog({required this.guardia, required this.dispositivo});

  final GuardiaIdentificado guardia;
  final DispositivoInfo dispositivo;

  @override
  ConsumerState<_AsistenciaDialog> createState() => _AsistenciaDialogState();
}

class _AsistenciaDialogState extends ConsumerState<_AsistenciaDialog> {
  final _observacionController = TextEditingController();
  bool _loading = false;
  String? _result;
  bool _success = false;

  @override
  void dispose() {
    _observacionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      await ref.read(operacionServiceProvider).createAttendance(
        widget.dispositivo.idDispositivo,
        latitud: '0', longitud: '0',
        observacion: _observacionController.text.trim().isEmpty ? null : _observacionController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _success = true;
        _result = 'Asistencia registrada correctamente.';
      });
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _result = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar asistencia'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.guardia.nombreCompleto,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            widget.dispositivo.puesto?.nombrePuesto ?? '',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _observacionController,
            decoration: const InputDecoration(
              labelText: 'Observación (opcional)',
            ),
            maxLines: 2,
            enabled: !_loading && !_success,
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Text(
              _result!,
              style: TextStyle(
                color: _success ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        if (!_success)
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Registrar'),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------
// Incident report dialog
// -----------------------------------------------------------------------

class _NovedadDialog extends ConsumerStatefulWidget {
  const _NovedadDialog({required this.guardia, required this.dispositivo});

  final GuardiaIdentificado guardia;
  final DispositivoInfo dispositivo;

  @override
  ConsumerState<_NovedadDialog> createState() => _NovedadDialogState();
}

class _NovedadDialogState extends ConsumerState<_NovedadDialog> {
  final _tipoController = TextEditingController(text: 'INCIDENCIA');
  final _descripcionController = TextEditingController();
  bool _loading = false;
  String? _result;
  bool _success = false;

  @override
  void dispose() {
    _tipoController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_descripcionController.text.trim().isEmpty) {
      setState(() => _result = 'La descripción es obligatoria.');
      return;
    }
    if (_loading) return;
    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      await ref.read(operacionServiceProvider).createIncident(
        widget.dispositivo.idDispositivo,
        tipo: _tipoController.text.trim(), descripcion: _descripcionController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _success = true;
        _result = 'Novedad reportada correctamente.';
      });
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _result = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reportar novedad'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.guardia.nombreCompleto,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              widget.dispositivo.puesto?.nombrePuesto ?? '',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tipoController,
              decoration: const InputDecoration(labelText: 'Tipo'),
              enabled: !_loading && !_success,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descripcionController,
              decoration: const InputDecoration(labelText: 'Descripción *'),
              maxLines: 3,
              enabled: !_loading && !_success,
            ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Text(
                _result!,
                style: TextStyle(
                  color: _success ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        if (!_success)
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Reportar'),
          ),
      ],
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
        color: esFijo ? AppColors.orange : Colors.blue.shade700,
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Error al cargar la sesión.';
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
