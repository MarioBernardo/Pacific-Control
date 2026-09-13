import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/authenticated_api_client.dart';
import '../../../theme/app_colors.dart';
import '../../auth/auth_provider.dart';
import '../models/puesto.dart';
import '../providers/puestos_provider.dart';

class PuestosPage extends ConsumerWidget {
  const PuestosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puestos = ref.watch(puestosProvider);
    final position = ref.watch(authControllerProvider).session?.employee.position;
    final canManage = {'ADMINISTRADOR', 'SUPERVISOR'}
        .contains(position?.trim().toUpperCase());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Puestos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar puestos',
            onPressed: () => ref.read(puestosProvider.notifier).reload(),
            icon: const Icon(Icons.refresh),
          ),
          if (canManage)
            IconButton(
              tooltip: 'Crear puesto',
              onPressed: () => _openForm(context, ref),
              icon: const Icon(Icons.add_business_outlined),
            ),
        ],
      ),
      body: puestos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          error: error,
          onRetry: () => ref.read(puestosProvider.notifier).reload(),
        ),
        data: (items) => items.isEmpty
            ? const _EmptyView()
            : RefreshIndicator(
                onRefresh: () => ref.read(puestosProvider.notifier).reload(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _PuestoTile(
                    puesto: items[index],
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
    Puesto? puesto,
  ]) async {
    final result = await showDialog<Puesto>(
      context: context,
      builder: (_) => _PuestoFormDialog(puesto: puesto),
    );
    if (result == null || !context.mounted) return;
    try {
      final controller = ref.read(puestosProvider.notifier);
      if (puesto == null) {
        await controller.create(result);
      } else {
        await controller.editPuesto(result);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(puesto == null ? 'Puesto creado.' : 'Puesto actualizado.')),
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _toggleStatus(
    BuildContext context,
    WidgetRef ref,
    Puesto puesto,
  ) async {
    try {
      await ref.read(puestosProvider.notifier).changeStatus(puesto);
    } on ApiException catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  void _showError(BuildContext context, ApiException error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.message)),
    );
  }
}

class _PuestoTile extends StatelessWidget {
  const _PuestoTile({
    required this.puesto,
    required this.canManage,
    required this.onEdit,
    required this.onToggle,
  });

  final Puesto puesto;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final active = puesto.estado.toLowerCase() == 'activo';
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: active ? AppColors.orangeSurface : AppColors.border,
          child: Icon(
            Icons.location_on_outlined,
            color: active ? AppColors.darkBlue : AppColors.mutedText,
          ),
        ),
        title: Text(puesto.nombrePuesto),
        subtitle: Text('${puesto.direccion}\nEstado: ${puesto.estado}'),
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

class _PuestoFormDialog extends StatefulWidget {
  const _PuestoFormDialog({this.puesto});

  final Puesto? puesto;

  @override
  State<_PuestoFormDialog> createState() => _PuestoFormDialogState();
}

class _PuestoFormDialogState extends State<_PuestoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late String _status;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.puesto?.nombrePuesto);
    _addressController = TextEditingController(text: widget.puesto?.direccion);
    _status = widget.puesto?.estado ?? 'activo';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.puesto != null;
    return AlertDialog(
      title: Text(editing ? 'Editar puesto' : 'Nuevo puesto'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre del puesto'),
              validator: _required,
            ),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Dirección'),
              validator: _required,
            ),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const [
                DropdownMenuItem(value: 'activo', child: Text('Activo')),
                DropdownMenuItem(value: 'inactivo', child: Text('Inactivo')),
              ],
              onChanged: (value) => setState(() => _status = value ?? 'activo'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: Text(editing ? 'Guardar' : 'Crear')),
      ],
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Campo obligatorio' : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Puesto(
        idPuesto: widget.puesto?.idPuesto,
        nombrePuesto: _nameController.text.trim(),
        direccion: _addressController.text.trim(),
        estado: _status,
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('No hay puestos registrados.'),
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
        : 'No se pudieron cargar los puestos.';
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
