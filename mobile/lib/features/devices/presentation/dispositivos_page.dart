import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api_client.dart';
import '../../../theme/app_colors.dart';
import '../../auth/auth_provider.dart';
import '../../positions/models/puesto.dart';
import '../../positions/providers/puestos_provider.dart';
import '../models/dispositivo.dart';
import '../providers/dispositivos_provider.dart';

class DispositivosPage extends ConsumerWidget {
  const DispositivosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispositivos = ref.watch(dispositivosProvider);
    final position = ref.watch(authControllerProvider).session?.employee.position;
    final canManage = {'ADMINISTRADOR', 'SUPERVISOR'}
        .contains(position?.trim().toUpperCase());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar dispositivos',
            onPressed: () => ref.read(dispositivosProvider.notifier).reload(),
            icon: const Icon(Icons.refresh),
          ),
          if (canManage)
            IconButton(
              tooltip: 'Crear dispositivo',
              onPressed: () => _openForm(context, ref),
              icon: const Icon(Icons.add_to_photos_outlined),
            ),
        ],
      ),
      body: dispositivos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          error: error,
          onRetry: () => ref.read(dispositivosProvider.notifier).reload(),
        ),
        data: (items) => items.isEmpty
            ? const _EmptyView()
            : RefreshIndicator(
                onRefresh: () => ref.read(dispositivosProvider.notifier).reload(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _DeviceTile(
                    dispositivo: items[index],
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
    Dispositivo? dispositivo,
  ]) async {
    final puestos = ref.read(puestosProvider).valueOrNull ?? <Puesto>[];
    if (puestos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe existir al menos un puesto.')),
      );
      return;
    }
    final result = await showDialog<Dispositivo>(
      context: context,
      builder: (_) => _DeviceFormDialog(
        dispositivo: dispositivo,
        puestos: puestos,
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      final controller = ref.read(dispositivosProvider.notifier);
      if (dispositivo == null) {
        await controller.create(result);
      } else {
        await controller.editDispositivo(result);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dispositivo == null
                  ? 'Dispositivo creado.'
                  : 'Dispositivo actualizado.',
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
    Dispositivo dispositivo,
  ) async {
    try {
      await ref.read(dispositivosProvider.notifier).changeStatus(dispositivo);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Estado actualizado.')),
        );
      }
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

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.dispositivo,
    required this.canManage,
    required this.onEdit,
    required this.onToggle,
  });

  final Dispositivo dispositivo;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final active = dispositivo.estado.toLowerCase() == 'activo';
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: active ? AppColors.orangeSurface : AppColors.border,
          child: Icon(
            Icons.phone_android_outlined,
            color: active ? AppColors.darkBlue : AppColors.mutedText,
          ),
        ),
        title: Text(dispositivo.codigoDispositivo),
        subtitle: Text(
          '${dispositivo.modelo ?? 'Modelo no indicado'}\n'
          'Puesto: ${dispositivo.idPuesto} | Estado: ${dispositivo.estado}',
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

class _DeviceFormDialog extends StatefulWidget {
  const _DeviceFormDialog({required this.puestos, this.dispositivo});

  final List<Puesto> puestos;
  final Dispositivo? dispositivo;

  @override
  State<_DeviceFormDialog> createState() => _DeviceFormDialogState();
}

class _DeviceFormDialogState extends State<_DeviceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _modelController;
  late final TextEditingController _statusController;
  late int? _selectedPuestoId;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(
      text: widget.dispositivo?.codigoDispositivo,
    );
    _modelController = TextEditingController(text: widget.dispositivo?.modelo);
    _statusController = TextEditingController(
      text: widget.dispositivo?.estado ?? 'activo',
    );
    _selectedPuestoId = widget.dispositivo?.idPuesto;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _modelController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.dispositivo != null;
    final selectedExists = widget.puestos.any((item) => item.idPuesto == _selectedPuestoId);
    return AlertDialog(
      title: Text(editing ? 'Editar dispositivo' : 'Nuevo dispositivo'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Código'),
                validator: _required,
              ),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(labelText: 'Modelo'),
              ),
              TextFormField(
                controller: _statusController,
                decoration: const InputDecoration(labelText: 'Estado'),
                validator: _required,
              ),
              DropdownButtonFormField<int>(
                initialValue: selectedExists ? _selectedPuestoId : null,
                decoration: const InputDecoration(labelText: 'Puesto'),
                items: [
                  for (final puesto in widget.puestos)
                    DropdownMenuItem(
                      value: puesto.idPuesto,
                      child: Text(puesto.nombrePuesto),
                    ),
                ],
                onChanged: (value) => setState(() => _selectedPuestoId = value),
                validator: (value) => value == null ? 'Seleccione un puesto' : null,
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

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Campo obligatorio' : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Dispositivo(
        idDispositivo: widget.dispositivo?.idDispositivo,
        codigoDispositivo: _codeController.text.trim(),
        modelo: _modelController.text.trim().isEmpty
            ? null
            : _modelController.text.trim(),
        estado: _statusController.text.trim(),
        idPuesto: _selectedPuestoId!,
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
        child: Text('No hay dispositivos registrados.'),
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
