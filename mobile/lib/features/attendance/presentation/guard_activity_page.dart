import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api_client.dart';
import '../../../widgets/app_back_button.dart';
import '../providers/administrative_reports_provider.dart';

class GuardActivityPage extends ConsumerStatefulWidget {
  const GuardActivityPage({super.key, required this.employeeId});
  final int employeeId;

  @override
  ConsumerState<GuardActivityPage> createState() => _GuardActivityPageState();
}

class _GuardActivityPageState extends ConsumerState<GuardActivityPage> {
  late int month = DateTime.now().month;
  late int year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final query = (employeeId: widget.employeeId, month: month, year: year);
    final state = ref.watch(guardMonthlySummaryProvider(query));
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Actividad del guardia'),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error is ApiException
                    ? error.message
                    : 'No se pudo cargar la actividad.',
              ),
              OutlinedButton(
                onPressed: () =>
                    ref.invalidate(guardMonthlySummaryProvider(query)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (summary) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: month,
                    decoration: const InputDecoration(labelText: 'Mes'),
                    items: [
                      for (var value = 1; value <= 12; value++)
                        DropdownMenuItem(value: value, child: Text('$value')),
                    ],
                    onChanged: (value) =>
                        setState(() => month = value ?? month),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: year,
                    decoration: const InputDecoration(labelText: 'Año'),
                    items: [
                      for (
                        var value = DateTime.now().year - 5;
                        value <= DateTime.now().year + 1;
                        value++
                      )
                        DropdownMenuItem(value: value, child: Text('$value')),
                    ],
                    onChanged: (value) => setState(() => year = value ?? year),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              summary.guard ?? 'Guardia sin asistencias en el período',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('Turnos realizados: ${summary.totalShifts}'),
            Text('12 HORAS: ${summary.twelveHourShifts}'),
            Text('24 HORAS: ${summary.twentyFourHourShifts}'),
            Text('Horas derivadas: ${summary.derivedHours}'),
            Text('Asistencias: ${summary.attendances}'),
            Text('Novedades asociadas: ${summary.incidents}'),
            Text(
              'Puestos: ${summary.positions.isEmpty ? 'Sin registros' : summary.positions.join(', ')}',
            ),
            const SizedBox(height: 20),
            Text('Historial', style: Theme.of(context).textTheme.titleMedium),
            if (summary.history.isEmpty)
              const Text('No hay actividad para el período seleccionado.')
            else
              for (final item in summary.history)
                Card(
                  child: ListTile(
                    title: Text(item['puesto'] as String),
                    subtitle: Text(
                      '${item['tipo_turno']} · ${_date(item['fecha_hora'] as String)}\n${item['estado']}',
                    ),
                    trailing: Icon(
                      item['tiene_ubicacion'] == true
                          ? Icons.location_on
                          : Icons.location_off,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

String _date(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}
