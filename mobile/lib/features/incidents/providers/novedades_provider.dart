import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../employees/models/empleado.dart';
import '../../employees/services/empleado_service.dart';
import '../../shifts/models/turno.dart';
import '../../shifts/services/turno_service.dart';
import '../models/novedad.dart';
import '../services/novedad_service.dart';

final empleadosForNovedadProvider = FutureProvider<List<Empleado>>(
  (ref) => ref.read(empleadoServiceProvider).getAll(),
);
final turnosForNovedadProvider = FutureProvider<List<Turno>>(
  (ref) => ref.read(turnoServiceProvider).getAll(),
);

final novedadesProvider =
    AsyncNotifierProvider<NovedadesController, List<Novedad>>(
      NovedadesController.new,
    );

class NovedadesController extends AsyncNotifier<List<Novedad>> {
  NovedadService get _service => ref.read(novedadServiceProvider);
  @override
  Future<List<Novedad>> build() => _service.getAll();
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_service.getAll);
  }

  Future<void> create(Novedad item) async {
    final created = await _service.create(item);
    state = AsyncData([...state.valueOrNull ?? <Novedad>[], created]);
  }

  Future<void> edit(Novedad item) async {
    final updated = await _service.update(item);
    state = AsyncData([
      for (final old in state.valueOrNull ?? <Novedad>[])
        if (old.idNovedad == updated.idNovedad) updated else old,
    ]);
  }

  Future<void> changeStatus(Novedad item) async {
    final updated = await _service.changeStatus(
      item.idNovedad!,
      item.estado.toLowerCase() == 'abierta' ? 'cerrada' : 'abierta',
    );
    state = AsyncData([
      for (final old in state.valueOrNull ?? <Novedad>[])
        if (old.idNovedad == updated.idNovedad) updated else old,
    ]);
  }
}
