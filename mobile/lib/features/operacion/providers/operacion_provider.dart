import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/services/dispositivo_service.dart';
import '../models/device_session.dart';
import '../services/operacion_service.dart';

// ------------------------------------------------------------------
// Device list with embedded puesto info
// Fetches standard device list and enriches each one via operacion API.
// ------------------------------------------------------------------

final dispositivosInfoProvider =
    FutureProvider.autoDispose<List<DispositivoInfo>>((ref) async {
      final dispositivoService = ref.read(dispositivoServiceProvider);
      final operService = ref.read(operacionServiceProvider);

      // Get all devices from the standard endpoint
      final rawList = await dispositivoService.getAll();

      // Enrich each device with puesto info from the operative endpoint
      final results = await Future.wait(
        rawList.map((d) => operService.getDeviceById(d.idDispositivo!)),
      );
      return results;
    });

// ------------------------------------------------------------------
// Session state for a specific device
// ------------------------------------------------------------------

final deviceSessionProvider =
    AsyncNotifierProviderFamily<DeviceSessionController, SesionOperativa, int>(
      DeviceSessionController.new,
    );

class DeviceSessionController
    extends FamilyAsyncNotifier<SesionOperativa, int> {
  OperacionService get _service => ref.read(operacionServiceProvider);

  @override
  Future<SesionOperativa> build(int deviceId) async {
    return _service.getSession(deviceId);
  }

  Future<void> identifyGuard(int empleadoId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _service.identifyGuard(arg, empleadoId),
    );
  }

  Future<void> clearSession() async {
    await _service.clearSession(arg);
    state = await AsyncValue.guard(() => _service.getSession(arg));
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.getSession(arg));
  }
}

// ------------------------------------------------------------------
// Available guards for a device
// ------------------------------------------------------------------

final deviceGuardsProvider = FutureProviderFamily<List<GuardiaDisponible>, int>(
  (ref, deviceId) =>
      ref.read(operacionServiceProvider).getAvailableGuards(deviceId),
);
