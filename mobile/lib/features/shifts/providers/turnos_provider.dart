import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../employees/models/empleado.dart';
import '../../employees/services/empleado_service.dart';
import '../../positions/models/puesto.dart';
import '../../positions/providers/puestos_provider.dart';
import '../models/turno.dart';
import '../services/turno_service.dart';

final empleadosForTurnoProvider = FutureProvider<List<Empleado>>(
  (ref) => ref.read(empleadoServiceProvider).getAll(),
);

final turnosProvider = AsyncNotifierProvider<TurnosController, List<Turno>>(
  TurnosController.new,
);

class TurnosController extends AsyncNotifier<List<Turno>> {
  TurnoService get _service => ref.read(turnoServiceProvider);

  @override
  Future<List<Turno>> build() => _service.getAll();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_service.getAll);
  }

  Future<void> create(Turno turno) async {
    final created = await _service.create(turno);
    state = AsyncData([...state.valueOrNull ?? <Turno>[], created]);
  }

  Future<void> editTurno(Turno turno) async {
    final updated = await _service.update(turno);
    state = AsyncData([
      for (final item in state.valueOrNull ?? <Turno>[])
        if (item.idTurno == updated.idTurno) updated else item,
    ]);
  }

  Future<void> changeStatus(Turno turno) async {
    final updated = await _service.changeStatus(
      turno.idTurno!,
      turno.estado.toLowerCase() == 'activo' ? 'inactivo' : 'activo',
    );
    state = AsyncData([
      for (final item in state.valueOrNull ?? <Turno>[])
        if (item.idTurno == updated.idTurno) updated else item,
    ]);
  }
}

final puestosForTurnoProvider = Provider<List<Puesto>>((ref) {
  return ref.watch(puestosProvider).valueOrNull ?? <Puesto>[];
});
