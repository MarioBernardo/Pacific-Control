import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api_client.dart';
import '../../../theme/app_colors.dart';
import '../../auth/auth_provider.dart';
import '../models/empleado.dart';
import '../providers/empleados_provider.dart';

class EmpleadosPage extends ConsumerWidget {
  const EmpleadosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empleados = ref.watch(empleadosProvider);
    final position = ref
        .watch(authControllerProvider)
        .session
        ?.employee
        .position
        .trim()
        .toUpperCase();
    final canManage = position == 'ADMINISTRADOR';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Empleados'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(empleadosProvider.notifier).reload(),
          ),
          if (canManage)
            IconButton(
              tooltip: 'Nuevo empleado',
              icon: const Icon(Icons.person_add_outlined),
              onPressed: () => _openForm(context, ref),
            ),
        ],
      ),
      body: empleados.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          error: error,
          onRetry: () => ref.read(empleadosProvider.notifier).reload(),
        ),
        data: (items) => items.isEmpty
            ? const _EmptyView()
            : RefreshIndicator(
                onRefresh: () => ref.read(empleadosProvider.notifier).reload(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _EmpleadoTile(
                    empleado: items[index],
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
    Empleado? empleado,
  ]) async {
    final result = await showDialog<Empleado>(
      context: context,
      builder: (_) => _EmpleadoFormDialog(empleado: empleado),
    );
    if (result == null || !context.mounted) return;
    try {
      final controller = ref.read(empleadosProvider.notifier);
      if (empleado == null) {
        await controller.create(result);
      } else {
        await controller.editEmpleado(result);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              empleado == null ? 'Empleado creado.' : 'Empleado actualizado.',
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
    Empleado empleado,
  ) async {
    try {
      await ref.read(empleadosProvider.notifier).changeStatus(empleado);
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

class _EmpleadoTile extends StatelessWidget {
  const _EmpleadoTile({
    required this.empleado,
    required this.canManage,
    required this.onEdit,
    required this.onToggle,
  });

  final Empleado empleado;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final active = empleado.estado;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: active ? AppColors.orangeSurface : AppColors.border,
          child: Icon(
            Icons.person,
            color: active ? AppColors.darkBlue : AppColors.mutedText,
          ),
        ),
        title: Text(
          '${empleado.apellidos} ${empleado.nombres}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${empleado.cargo} | ${empleado.cedula}\n${empleado.correo}',
        ),
        isThreeLine: true,
        trailing: canManage
            ? PopupMenuButton<String>(
                onSelected: (value) => value == 'edit' ? onEdit() : onToggle(),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'status',
                    child: Text(active ? 'Desactivar' : 'Activar'),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _EmpleadoFormDialog extends StatefulWidget {
  const _EmpleadoFormDialog({this.empleado});

  final Empleado? empleado;

  @override
  State<_EmpleadoFormDialog> createState() => _EmpleadoFormDialogState();
}

class _EmpleadoFormDialogState extends State<_EmpleadoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cedulaController;
  late final TextEditingController _nombresController;
  late final TextEditingController _apellidosController;
  late final TextEditingController _correoController;
  late final TextEditingController _telefonoController;
  late String _cargo;

  static const _cargos = ['ADMINISTRADOR', 'SUPERVISOR', 'GUARDIA'];

  @override
  void initState() {
    super.initState();
    final e = widget.empleado;
    _cedulaController = TextEditingController(text: e?.cedula);
    _nombresController = TextEditingController(text: e?.nombres);
    _apellidosController = TextEditingController(text: e?.apellidos);
    _correoController = TextEditingController(text: e?.correo);
    _telefonoController = TextEditingController(text: e?.telefono);
    _cargo = e?.cargo ?? 'GUARDIA';
    if (!_cargos.contains(_cargo)) _cargo = 'GUARDIA';
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.empleado != null;
    return AlertDialog(
      title: Text(editing ? 'Editar empleado' : 'Nuevo empleado'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_cedulaController, 'Cédula'),
              _field(_nombresController, 'Nombres'),
              _field(_apellidosController, 'Apellidos'),
              _field(
                _correoController,
                'Correo',
                keyboardType: TextInputType.emailAddress,
              ),
              _field(
                _telefonoController,
                'Teléfono',
                keyboardType: TextInputType.phone,
              ),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _cargo,
                decoration: const InputDecoration(labelText: 'Cargo'),
                items: [
                  for (final c in _cargos)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _cargo = v ?? _cargo),
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

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: keyboardType,
      validator: (v) =>
          v == null || v.trim().isEmpty ? 'Campo obligatorio' : null,
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Empleado(
        idEmpleado: widget.empleado?.idEmpleado ?? 0,
        cedula: _cedulaController.text.trim(),
        nombres: _nombresController.text.trim(),
        apellidos: _apellidosController.text.trim(),
        correo: _correoController.text.trim(),
        telefono: _telefonoController.text.trim(),
        cargo: _cargo,
        estado: widget.empleado?.estado ?? true,
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
      child: Text('No hay empleados registrados.'),
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
        : 'No se pudieron cargar los empleados.';
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
