import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api_client.dart';
import '../../../config/app_environment.dart';
import '../../../widgets/app_back_button.dart';
import '../../auth/auth_provider.dart';
import '../../employees/models/empleado.dart';
import '../../shifts/models/turno.dart';
import '../models/novedad.dart';
import '../providers/novedades_provider.dart';

class NovedadesPage extends ConsumerWidget {
  const NovedadesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(novedadesProvider);
    final role = ref
        .watch(authControllerProvider)
        .session
        ?.employee
        .position
        .toUpperCase();
    final canEdit = {'ADMINISTRADOR', 'SUPERVISOR'}.contains(role);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Novedades'),
        actions: [
          IconButton(
            tooltip: 'Actualizar novedades',
            onPressed: () => ref.read(novedadesProvider.notifier).reload(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Crear novedad',
            onPressed: () => _openForm(context, ref),
            icon: const Icon(Icons.add_alert),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          error: error,
          onRetry: () => ref.read(novedadesProvider.notifier).reload(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No hay novedades registradas.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(novedadesProvider.notifier).reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return _NovedadTile(
                  item: item,
                  canEdit: canEdit,
                  onEdit: () => _openForm(context, ref, item),
                  onToggle: () => _toggleStatus(context, ref, item),
                  onDetail: () => _showDetail(context, ref, item),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, [
    Novedad? item,
  ]) async {
    try {
      final session = ref.read(authControllerProvider).session!.employee;
      final canLoadEmployees = {
        'ADMINISTRADOR',
        'SUPERVISOR',
      }.contains(session.position.toUpperCase());
      final employees = canLoadEmployees
          ? await ref.read(empleadosForNovedadProvider.future)
          : [
              Empleado(
                idEmpleado: session.id,
                cedula: '',
                nombres: session.firstName,
                apellidos: session.lastName,
                correo: session.email,
                telefono: '',
                cargo: session.position,
                estado: true,
              ),
            ];
      final shifts = await ref.read(turnosForNovedadProvider.future);
      if (!context.mounted) return;
      final result = await showDialog<Novedad>(
        context: context,
        builder: (_) =>
            _NovedadForm(item: item, employees: employees, shifts: shifts),
      );
      if (result == null) return;
      if (item == null) {
        await ref.read(novedadesProvider.notifier).create(result);
      } else {
        await ref.read(novedadesProvider.notifier).edit(result);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Novedad guardada.')));
      }
    } on ApiException catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _toggleStatus(
    BuildContext context,
    WidgetRef ref,
    Novedad item,
  ) async {
    try {
      await ref.read(novedadesProvider.notifier).changeStatus(item);
    } on ApiException catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  void _showError(BuildContext context, ApiException error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.message)));
  }

  void _showDetail(BuildContext context, WidgetRef ref, Novedad item) {
    final token = ref.read(authControllerProvider).session?.accessToken;
    final base = AppEnvironment.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Detalle de novedad'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Guardia: ${item.guardiaNombre ?? 'No disponible'}'),
              Text('Puesto: ${item.puestoNombre ?? 'No disponible'}'),
              Text('Fecha y hora: ${item.fechaHoraLegible}'),
              Text('Turno: ${item.tipoTurno ?? 'No disponible'}'),
              Text('Tipo: ${item.tipo}'),
              Text('Estado: ${item.estado}'),
              const SizedBox(height: 10),
              Text(item.descripcion),
              const SizedBox(height: 12),
              if (item.evidenciaFoto == null)
                const Text('Sin evidencia fotográfica.')
              else
                Image.network(
                  '$base/novedades/${item.idNovedad}/evidencia',
                  headers: token == null
                      ? null
                      : {'Authorization': 'Bearer $token'},
                  errorBuilder: (_, _, _) =>
                      const Text('Evidencia fotográfica no disponible.'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ATRÁS'),
          ),
        ],
      ),
    );
  }
}

class _NovedadTile extends StatelessWidget {
  const _NovedadTile({
    required this.item,
    required this.canEdit,
    required this.onEdit,
    required this.onToggle,
    required this.onDetail,
  });

  final Novedad item;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(item.guardiaNombre ?? item.tipo),
        subtitle: Text(
          '${item.puestoNombre ?? 'Puesto no disponible'} · ${item.tipo}\n${item.fechaHoraLegible} · ${item.estado.toUpperCase()}\n${item.descripcion}',
        ),
        isThreeLine: true,
        onTap: onDetail,
        trailing: canEdit
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else {
                    onToggle();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'status', child: Text('Cambiar estado')),
                ],
              )
            : null,
      ),
    );
  }
}

class _NovedadForm extends StatefulWidget {
  const _NovedadForm({
    required this.employees,
    required this.shifts,
    this.item,
  });

  final Novedad? item;
  final List<Empleado> employees;
  final List<Turno> shifts;

  @override
  State<_NovedadForm> createState() => _NovedadFormState();
}

class _NovedadFormState extends State<_NovedadForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _typeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dateController;
  late final TextEditingController _statusController;
  late int? _employeeId;
  late int? _shiftId;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _typeController = TextEditingController(text: item?.tipo);
    _descriptionController = TextEditingController(text: item?.descripcion);
    _dateController = TextEditingController(
      text: item?.fechaHora ?? DateTime.now().toIso8601String(),
    );
    _statusController = TextEditingController(text: item?.estado ?? 'abierta');
    _employeeId = item?.idEmpleado;
    _shiftId = item?.idTurno;
  }

  @override
  void dispose() {
    _typeController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    return AlertDialog(
      title: Text(editing ? 'Editar novedad' : 'Nueva novedad'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_typeController, 'Tipo'),
              _field(_descriptionController, 'Descripción'),
              _field(_dateController, 'Fecha y hora ISO'),
              _field(_statusController, 'Estado'),
              _employeeDropdown(),
              _shiftDropdown(),
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

  Widget _field(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Campo obligatorio' : null,
    );
  }

  Widget _employeeDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _validId(
        _employeeId,
        widget.employees.map((employee) => employee.idEmpleado),
      ),
      decoration: const InputDecoration(labelText: 'Empleado'),
      items: [
        for (final employee in widget.employees)
          DropdownMenuItem(
            value: employee.idEmpleado,
            child: Text('${employee.nombres} ${employee.apellidos}'),
          ),
      ],
      onChanged: (value) => setState(() => _employeeId = value),
      validator: (value) => value == null ? 'Seleccione empleado' : null,
    );
  }

  Widget _shiftDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _validId(
        _shiftId,
        widget.shifts.map((shift) => shift.idTurno!),
      ),
      decoration: const InputDecoration(labelText: 'Turno'),
      items: [
        for (final shift in widget.shifts)
          DropdownMenuItem(
            value: shift.idTurno,
            child: Text('${shift.fecha} ${shift.horaInicio ?? 'Sin hora'}'),
          ),
      ],
      onChanged: (value) => setState(() => _shiftId = value),
      validator: (value) => value == null ? 'Seleccione turno' : null,
    );
  }

  int? _validId(int? value, Iterable<int> options) {
    return value != null && options.contains(value) ? value : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Novedad(
        idNovedad: widget.item?.idNovedad,
        tipo: _typeController.text.trim(),
        descripcion: _descriptionController.text.trim(),
        fechaHora: _dateController.text.trim(),
        estado: _statusController.text.trim(),
        idEmpleado: _employeeId!,
        idTurno: _shiftId!,
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
        : 'No se pudieron cargar las novedades.';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
