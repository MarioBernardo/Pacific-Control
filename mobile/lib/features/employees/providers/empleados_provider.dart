import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/empleado.dart';
import '../services/empleado_service.dart';

final empleadosProvider =
    AsyncNotifierProvider<EmpleadosController, List<Empleado>>(
  EmpleadosController.new,
);

class EmpleadosController extends AsyncNotifier<List<Empleado>> {
  EmpleadoService get _service => ref.read(empleadoServiceProvider);

  @override
  Future<List<Empleado>> build() => _service.getAll();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_service.getAll);
  }

  Future<void> create(Empleado empleado) async {
    final created = await _service.create(empleado);
    state = AsyncData([...state.valueOrNull ?? <Empleado>[], created]);
  }

  Future<void> editEmpleado(Empleado empleado) async {
    final updated = await _service.update(empleado);
    state = AsyncData([
      for (final item in state.valueOrNull ?? <Empleado>[])
        if (item.idEmpleado == updated.idEmpleado) updated else item,
    ]);
  }

  Future<void> changeStatus(Empleado empleado) async {
    final updated = await _service.changeStatus(
      empleado.idEmpleado,
      !empleado.estado,
    );
    state = AsyncData([
      for (final item in state.valueOrNull ?? <Empleado>[])
        if (item.idEmpleado == updated.idEmpleado) updated else item,
    ]);
  }
}
