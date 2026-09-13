import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dispositivo.dart';
import '../services/dispositivo_service.dart';

final dispositivosProvider =
    AsyncNotifierProvider<DispositivosController, List<Dispositivo>>(
      DispositivosController.new,
    );

class DispositivosController extends AsyncNotifier<List<Dispositivo>> {
  DispositivoService get _service => ref.read(dispositivoServiceProvider);

  @override
  Future<List<Dispositivo>> build() => _service.getAll();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_service.getAll);
  }

  Future<void> create(Dispositivo dispositivo) async {
    final created = await _service.create(dispositivo);
    state = AsyncData([...state.valueOrNull ?? <Dispositivo>[], created]);
  }

  Future<void> editDispositivo(Dispositivo dispositivo) async {
    final updated = await _service.update(dispositivo);
    state = AsyncData([
      for (final item in state.valueOrNull ?? <Dispositivo>[])
        if (item.idDispositivo == updated.idDispositivo) updated else item,
    ]);
  }

  Future<void> changeStatus(Dispositivo dispositivo) async {
    final updated = await _service.changeStatus(
      dispositivo.idDispositivo!,
      dispositivo.estado.toLowerCase() == 'activo' ? 'inactivo' : 'activo',
    );
    state = AsyncData([
      for (final item in state.valueOrNull ?? <Dispositivo>[])
        if (item.idDispositivo == updated.idDispositivo) updated else item,
    ]);
  }
}
