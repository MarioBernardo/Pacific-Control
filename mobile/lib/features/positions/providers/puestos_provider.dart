import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/puesto.dart';
import '../services/puesto_service.dart';

final puestosProvider = AsyncNotifierProvider<PuestosController, List<Puesto>>(
  PuestosController.new,
);

class PuestosController extends AsyncNotifier<List<Puesto>> {
  PuestoService get _service => ref.read(puestoServiceProvider);

  @override
  Future<List<Puesto>> build() => _service.getAll();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_service.getAll);
  }

  Future<void> create(Puesto puesto) async {
    final created = await _service.create(puesto);
    state = AsyncData([...state.valueOrNull ?? <Puesto>[], created]);
  }

  Future<void> editPuesto(Puesto puesto) async {
    final updated = await _service.update(puesto);
    state = AsyncData([
      for (final item in state.valueOrNull ?? <Puesto>[])
        if (item.idPuesto == updated.idPuesto) updated else item,
    ]);
  }

  Future<void> changeStatus(Puesto puesto) async {
    final updated = await _service.changeStatus(
      puesto.idPuesto!,
      puesto.estado == 'activo' ? 'inactivo' : 'activo',
    );
    state = AsyncData([
      for (final item in state.valueOrNull ?? <Puesto>[])
        if (item.idPuesto == updated.idPuesto) updated else item,
    ]);
  }
}
