import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api_client.dart';
import '../../../theme/app_colors.dart';
import '../../auth/auth_provider.dart';
import '../../employees/models/empleado.dart';
import '../../positions/models/puesto.dart';
import '../../positions/providers/puestos_provider.dart';
import '../models/turno.dart';
import '../providers/turnos_provider.dart';

class TurnosPage extends ConsumerWidget {
  const TurnosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final turnos = ref.watch(turnosProvider);
    final position = ref
        .watch(authControllerProvider)
        .session
        ?.employee
        .position;
    final canManage = {
      'ADMINISTRADOR',
      'SUPERVISOR',
    }.contains(position?.trim().toUpperCase());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turnos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar turnos',
            onPressed: () => ref.read(turnosProvider.notifier).reload(),
            icon: const Icon(Icons.refresh),
          ),
          if (canManage)
            IconButton(
              tooltip: 'Crear turno',
              onPressed: () => _openForm(context, ref),
              icon: const Icon(Icons.add_alarm),
            ),
        ],
      ),
      body: turnos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          error: error,
          onRetry: () => ref.read(turnosProvider.notifier).reload(),
        ),
        data: (items) => items.isEmpty
            ? const _EmptyView()
            : RefreshIndicator(
                onRefresh: () => ref.read(turnosProvider.notifier).reload(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _TurnoTile(
                    turno: items[index],
                    canManage: canManage,
                    onEdit: () => _openForm(context, ref, items[index]),
                    onToggle: () => _toggleStatus(context, ref, items[index]),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, [
    Turno? turno,
  ]) async {
    try {
      final results = await Future.wait([
        ref.read(empleadosForTurnoProvider.future),
        ref.read(puestosProvider.future),
      ]);
      if (!context.mounted) return;
      final empleados = results[0] as List<Empleado>;
      final puestos = results[1] as List<Puesto>;
      if (empleados.isEmpty || puestos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debe existir al menos un empleado y un puesto.'),
          ),
        );
        return;
      }
      final result = await showDialog<Turno>(
        context: context,
        builder: (_) => _TurnoFormDialog(
          turno: turno,
          empleados: empleados,
          puestos: puestos,
        ),
      );
      if (result == null || !context.mounted) return;
      final controller = ref.read(turnosProvider.notifier);
      if (turno == null) {
        await controller.create(result);
      } else {
        await controller.editTurno(result);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              turno == null ? 'Turno creado.' : 'Turno actualizado.',
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _toggleStatus(
    BuildContext context,
    WidgetRef ref,
    Turno turno,
  ) async {
    try {
      await ref.read(turnosProvider.notifier).changeStatus(turno);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Estado actualizado.')));
      }
    } on ApiException catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  void _showError(BuildContext context, ApiException error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.message)));
  }
}

class _TurnoTile extends StatelessWidget {
  const _TurnoTile({
    required this.turno,
    required this.canManage,
    required this.onEdit,
    required this.onToggle,
  });

  final Turno turno;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final active = turno.estado.toLowerCase() == 'activo';
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: active ? AppColors.orangeSurface : AppColors.border,
          child: Icon(
            Icons.schedule,
            color: active ? AppColors.darkBlue : AppColors.mutedText,
          ),
        ),
        title: Text('${turno.fecha} | ${turno.horaInicio} - ${turno.horaFin}'),
        subtitle: Text(
          'Empleado: ${turno.idEmpleado}\nPuesto: ${turno.idPuesto} | ${turno.tipoTurno}\nAsignación: ${turno.tipoAsignacion} | Estado: ${turno.estado}',
        ),
        isThreeLine: true,
        trailing: canManage
            ? PopupMenuButton<String>(
                onSelected: (value) => value == 'edit' ? onEdit() : onToggle(),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'status',
                    child: Text(active ? 'Marcar inactivo' : 'Marcar activo'),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _TurnoFormDialog extends StatefulWidget {
  const _TurnoFormDialog({
    required this.empleados,
    required this.puestos,
    this.turno,
  });

  final Turno? turno;
  final List<Empleado> empleados;
  final List<Puesto> puestos;

  @override
  State<_TurnoFormDialog> createState() => _TurnoFormDialogState();
}

class _TurnoFormDialogState extends State<_TurnoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late final TextEditingController _statusController;
  late int? _employeeId;
  late int? _puestoId;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: widget.turno?.fecha);
    _startController = TextEditingController(text: widget.turno?.horaInicio);
    _endController = TextEditingController(text: widget.turno?.horaFin);
    _statusController = TextEditingController(
      text: widget.turno?.estado ?? 'activo',
    );
    _employeeId = widget.turno?.idEmpleado;
    _puestoId = widget.turno?.idPuesto;
  }

  @override
  void dispose() {
    _dateController.dispose();
    _startController.dispose();
    _endController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.turno != null;
    return AlertDialog(
      title: Text(editing ? 'Editar turno' : 'Nuevo turno'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Fecha (YYYY-MM-DD)',
                ),
                onTap: _pickDate,
                validator: _required,
              ),
              TextFormField(
                controller: _startController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Hora inicio (HH:MM:SS)',
                ),
                onTap: () => _pickTime(_startController),
                validator: _required,
              ),
              TextFormField(
                controller: _endController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Hora fin (HH:MM:SS)',
                ),
                onTap: () => _pickTime(_endController),
                validator: _required,
              ),
              TextFormField(
                controller: _statusController,
                decoration: const InputDecoration(labelText: 'Estado'),
                validator: _required,
              ),
              DropdownButtonFormField<int>(
                initialValue:
                    widget.empleados.any(
                      (item) => item.idEmpleado == _employeeId,
                    )
                    ? _employeeId
                    : null,
                decoration: const InputDecoration(labelText: 'Empleado'),
                items: [
                  for (final empleado in widget.empleados)
                    DropdownMenuItem(
                      value: empleado.idEmpleado,
                      child: Text('${empleado.nombres} ${empleado.apellidos}'),
                    ),
                ],
                onChanged: (value) => setState(() => _employeeId = value),
                validator: (value) =>
                    value == null ? 'Seleccione un empleado' : null,
              ),
              DropdownButtonFormField<int>(
                initialValue:
                    widget.puestos.any((item) => item.idPuesto == _puestoId)
                    ? _puestoId
                    : null,
                decoration: const InputDecoration(labelText: 'Puesto'),
                items: [
                  for (final puesto in widget.puestos)
                    DropdownMenuItem(
                      value: puesto.idPuesto,
                      child: Text(puesto.nombrePuesto),
                    ),
                ],
                onChanged: (value) => setState(() => _puestoId = value),
                validator: (value) =>
                    value == null ? 'Seleccione un puesto' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(editing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dateController.text) ?? DateTime.now();
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (value != null) {
      _dateController.text = _isoDate(value);
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final current = _parseTime(controller.text) ?? TimeOfDay.now();
    final value = await showTimePicker(context: context, initialTime: current);
    if (value != null) controller.text = _isoTime(value);
  }

  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _isoTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obligatorio' : null;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Turno(
        idTurno: widget.turno?.idTurno,
        fecha: _dateController.text.trim(),
        horaInicio: _startController.text.trim(),
        horaFin: _endController.text.trim(),
        estado: _statusController.text.trim(),
        tipoTurno: '24 HORAS',
        tipoAsignacion: 'FIJO',
        idEmpleado: _employeeId!,
        idPuesto: _puestoId!,
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text('No hay turnos registrados.'),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : 'No se pudieron cargar los turnos.';
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
