import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/authenticated_api_client.dart';
import '../../../widgets/app_back_button.dart';
import '../models/administrative_reports.dart';
import '../providers/administrative_reports_provider.dart';

class PersonnelOnShiftPage extends ConsumerWidget {
  const PersonnelOnShiftPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(personnelOnShiftProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Personal en turno'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => ref.invalidate(personnelOnShiftProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Error(
          message: error is ApiException
              ? error.message
              : 'No se pudo cargar el personal en turno.',
          retry: () => ref.invalidate(personnelOnShiftProvider),
        ),
        data: (items) => items.isEmpty
            ? const Center(
                child: Text('No hay personal en turno en este momento.'),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, index) => _PersonnelCard(
                  items[index],
                  onTap: () => context.push(
                    '/empleados/${items[index].employeeId}/actividad',
                  ),
                ),
              ),
      ),
    );
  }
}

class _PersonnelCard extends StatelessWidget {
  const _PersonnelCard(this.item, {required this.onTap});
  final PersonnelOnShift item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.shield_outlined),
      title: Text(item.guard),
      subtitle: Text(
        '${item.position} · ${item.shiftType}\nEntrada: ${_date(item.startedAt)}\nFin estimado: ${_date(item.endsAt)}',
      ),
      isThreeLine: true,
      trailing: Text(item.status.toUpperCase()),
      onTap: onTap,
    ),
  );
}

String _date(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        OutlinedButton(onPressed: retry, child: const Text('Reintentar')),
      ],
    ),
  );
}
