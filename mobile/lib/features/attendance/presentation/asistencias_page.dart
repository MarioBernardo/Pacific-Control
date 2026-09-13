import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api_client.dart';
import '../../../theme/app_colors.dart';
import '../../auth/auth_provider.dart';
import '../../devices/models/dispositivo.dart';
import '../../employees/models/empleado.dart';
import '../../shifts/models/turno.dart';
import '../models/asistencia.dart';
import '../providers/asistencias_provider.dart';

class AsistenciasPage extends ConsumerWidget {
  const AsistenciasPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(asistenciasProvider);
    final role = ref
        .watch(authControllerProvider)
        .session
        ?.employee
        .position
        .toUpperCase();
    final canEdit = {'ADMINISTRADOR', 'SUPERVISOR'}.contains(role);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistencias'),
        actions: [
          IconButton(
            onPressed: () => ref.read(asistenciasProvider.notifier).reload(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () => _openForm(context, ref),
            icon: const Icon(Icons.add_task),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          e,
          () => ref.read(asistenciasProvider.notifier).reload(),
        ),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No hay asistencias registradas.'))
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(asistenciasProvider.notifier).reload(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (_, i) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.fact_check,
                        color: AppColors.darkBlue,
                      ),
                      title: Text(items[i].fechaHora),
                      subtitle: Text(
                        'Empleado: ${items[i].idEmpleado} | Turno: ${items[i].idTurno}\nEstado: ${items[i].estado}',
                      ),
                      isThreeLine: true,
                      trailing: canEdit
                          ? PopupMenuButton<String>(
                              onSelected: (v) => v == 'edit'
                                  ? _openForm(context, ref, items[i])
                                  : _toggle(context, ref, items[i]),
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                const PopupMenuItem(
                                  value: 'status',
                                  child: Text('Cambiar estado'),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, [
    Asistencia? item,
  ]) async {
    try {
      final sessionEmployee = ref
          .read(authControllerProvider)
          .session!
          .employee;
      final role = sessionEmployee.position.toUpperCase();
      final employees = {'ADMINISTRADOR', 'SUPERVISOR'}.contains(role)
          ? await ref.read(empleadosForAsistenciaProvider.future)
          : [
              Empleado(
                idEmpleado: sessionEmployee.id,
                cedula: '',
                nombres: sessionEmployee.firstName,
                apellidos: sessionEmployee.lastName,
                correo: sessionEmployee.email,
                telefono: '',
                cargo: sessionEmployee.position,
                estado: true,
              ),
            ];
      final results = await Future.wait([
        ref.read(turnosForAsistenciaProvider.future),
        ref.read(dispositivosForAsistenciaProvider.future),
      ]);
      if (!context.mounted) return;
      final result = await showDialog<Asistencia>(
        context: context,
        builder: (_) => _Form(
          item: item,
          employees: employees,
          shifts: results[0] as List<Turno>,
          devices: results[1] as List<Dispositivo>,
        ),
      );
      if (result == null) {
        return;
      }
      if (item == null) {
        await ref.read(asistenciasProvider.notifier).create(result);
      } else {
        await ref.read(asistenciasProvider.notifier).edit(result);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Asistencia guardada.')));
      }
    } on ApiException catch (e) {
      if (context.mounted) _show(context, e);
    }
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    Asistencia item,
  ) async {
    try {
      await ref.read(asistenciasProvider.notifier).changeStatus(item);
    } on ApiException catch (e) {
      if (context.mounted) _show(context, e);
    }
  }

  void _show(BuildContext c, ApiException e) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(e.message)));
}

class _Form extends StatefulWidget {
  const _Form({
    this.item,
    required this.employees,
    required this.shifts,
    required this.devices,
  });
  final Asistencia? item;
  final List<Empleado> employees;
  final List<Turno> shifts;
  final List<Dispositivo> devices;
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final keyForm = GlobalKey<FormState>();
  late final TextEditingController date, lat, lon, status, observation;
  late int? employee, shift, device;
  @override
  void initState() {
    super.initState();
    final i = widget.item;
    date = TextEditingController(
      text: i?.fechaHora ?? DateTime.now().toIso8601String(),
    );
    lat = TextEditingController(text: i?.latitud ?? '0');
    lon = TextEditingController(text: i?.longitud ?? '0');
    status = TextEditingController(text: i?.estado ?? 'registrada');
    observation = TextEditingController(text: i?.observacion);
    employee = i?.idEmpleado;
    shift = i?.idTurno;
    device = i?.idDispositivo;
  }

  @override
  void dispose() {
    date.dispose();
    lat.dispose();
    lon.dispose();
    status.dispose();
    observation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'Nueva asistencia' : 'Editar asistencia'),
    content: Form(
      key: keyForm,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(date, 'Fecha y hora ISO'),
            _field(lat, 'Latitud'),
            _field(lon, 'Longitud'),
            _field(status, 'Estado'),
            _field(observation, 'Observación', required: false),
            _dropEmployee(),
            _dropShift(),
            _dropDevice(),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Guardar')),
    ],
  );
  Widget _field(
    TextEditingController c,
    String label, {
    bool required = true,
  }) => TextFormField(
    controller: c,
    decoration: InputDecoration(labelText: label),
    validator: required
        ? (v) => v == null || v.trim().isEmpty ? 'Campo obligatorio' : null
        : null,
  );
  DropdownButtonFormField<int> _dropEmployee() => DropdownButtonFormField<int>(
    initialValue:
        employee != null &&
            widget.employees.any((e) => e.idEmpleado == employee)
        ? employee
        : null,
    decoration: const InputDecoration(labelText: 'Empleado'),
    items: [
      for (final e in widget.employees)
        DropdownMenuItem(
          value: e.idEmpleado,
          child: Text('${e.nombres} ${e.apellidos}'),
        ),
    ],
    onChanged: (v) => setState(() => employee = v),
    validator: (v) => v == null ? 'Seleccione empleado' : null,
  );
  DropdownButtonFormField<int> _dropShift() => DropdownButtonFormField<int>(
    initialValue: shift != null && widget.shifts.any((e) => e.idTurno == shift)
        ? shift
        : null,
    decoration: const InputDecoration(labelText: 'Turno'),
    items: [
      for (final e in widget.shifts)
        DropdownMenuItem(
          value: e.idTurno,
          child: Text('${e.fecha} ${e.horaInicio}'),
        ),
    ],
    onChanged: (v) => setState(() => shift = v),
    validator: (v) => v == null ? 'Seleccione turno' : null,
  );
  DropdownButtonFormField<int> _dropDevice() => DropdownButtonFormField<int>(
    initialValue:
        device != null && widget.devices.any((e) => e.idDispositivo == device)
        ? device
        : null,
    decoration: const InputDecoration(labelText: 'Dispositivo'),
    items: [
      for (final e in widget.devices)
        DropdownMenuItem(
          value: e.idDispositivo,
          child: Text(e.codigoDispositivo),
        ),
    ],
    onChanged: (v) => setState(() => device = v),
    validator: (v) => v == null ? 'Seleccione dispositivo' : null,
  );
  void _submit() {
    if (!keyForm.currentState!.validate()) return;
    Navigator.pop(
      context,
      Asistencia(
        idAsistencia: widget.item?.idAsistencia,
        fechaHora: date.text.trim(),
        latitud: lat.text.trim(),
        longitud: lon.text.trim(),
        foto: widget.item?.foto,
        observacion: observation.text.trim().isEmpty
            ? null
            : observation.text.trim(),
        estado: status.text.trim(),
        idEmpleado: employee!,
        idTurno: shift!,
        idDispositivo: device!,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView(this.error, this.retry);
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext c) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          error is ApiException
              ? (error as ApiException).message
              : 'No se pudieron cargar las asistencias.',
        ),
        OutlinedButton(onPressed: retry, child: const Text('Reintentar')),
      ],
    ),
  );
}
