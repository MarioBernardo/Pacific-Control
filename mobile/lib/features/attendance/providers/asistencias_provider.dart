import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/models/dispositivo.dart';
import '../../devices/services/dispositivo_service.dart';
import '../../employees/models/empleado.dart';
import '../../employees/services/empleado_service.dart';
import '../../shifts/models/turno.dart';
import '../../shifts/services/turno_service.dart';
import '../models/asistencia.dart';
import '../services/asistencia_service.dart';

final empleadosForAsistenciaProvider = FutureProvider<List<Empleado>>(
  (ref) => ref.read(empleadoServiceProvider).getAll(),
);
final turnosForAsistenciaProvider = FutureProvider<List<Turno>>(
  (ref) => ref.read(turnoServiceProvider).getAll(),
);
final dispositivosForAsistenciaProvider = FutureProvider<List<Dispositivo>>(
  (ref) => ref.read(dispositivoServiceProvider).getAll(),
);

final asistenciasProvider =
    AsyncNotifierProvider<AsistenciasController, List<Asistencia>>(
      AsistenciasController.new,
    );

class AsistenciasController extends AsyncNotifier<List<Asistencia>> {
  AsistenciaService get _service => ref.read(asistenciaServiceProvider);
  @override
  Future<List<Asistencia>> build() => _service.getAll();
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_service.getAll);
  }

  Future<void> create(Asistencia item) async {
    final created = await _service.create(item);
    state = AsyncData([...state.valueOrNull ?? <Asistencia>[], created]);
  }

  Future<void> edit(Asistencia item) async {
    final updated = await _service.update(item);
    state = AsyncData([
      for (final old in state.valueOrNull ?? <Asistencia>[])
        if (old.idAsistencia == updated.idAsistencia) updated else old,
    ]);
  }

  Future<void> changeStatus(Asistencia item) async {
    final updated = await _service.changeStatus(
      item.idAsistencia!,
      item.estado.toLowerCase() == 'activo' ? 'inactivo' : 'activo',
    );
    state = AsyncData([
      for (final old in state.valueOrNull ?? <Asistencia>[])
        if (old.idAsistencia == updated.idAsistencia) updated else old,
    ]);
  }
}
