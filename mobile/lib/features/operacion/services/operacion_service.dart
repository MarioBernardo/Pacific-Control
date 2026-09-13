import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api_client.dart';
import '../../auth/auth_provider.dart';
import '../models/device_session.dart';

final operacionServiceProvider = Provider<OperacionService>(
  (ref) => OperacionService(ref.read(authenticatedApiClientProvider)),
);

class OperacionService {
  OperacionService(this._apiClient);

  final AuthenticatedApiClient _apiClient;

  Future<DispositivoInfo> getDeviceById(int deviceId) async {
    final response =
        await _apiClient.get('/operacion/dispositivos/$deviceId')
            as Map<String, dynamic>;
    return DispositivoInfo.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<DispositivoInfo> getDeviceByCodigo(String codigo) async {
    final response =
        await _apiClient.get('/operacion/dispositivos/codigo/$codigo')
            as Map<String, dynamic>;
    return DispositivoInfo.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<List<GuardiaDisponible>> getAvailableGuards(int deviceId) async {
    final response =
        await _apiClient.get('/operacion/dispositivos/$deviceId/guardias')
            as Map<String, dynamic>;
    final list = response['data'] as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(GuardiaDisponible.fromJson)
        .toList();
  }

  Future<SesionOperativa> getSession(int deviceId) async {
    final response =
        await _apiClient.get('/operacion/dispositivos/$deviceId/sesion')
            as Map<String, dynamic>;
    return SesionOperativa.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<SesionOperativa> identifyGuard(
    int deviceId,
    int empleadoId,
  ) async {
    final response = await _apiClient.post(
      '/operacion/dispositivos/$deviceId/sesion/identificar',
      body: {'id_empleado': empleadoId},
    ) as Map<String, dynamic>;
    return SesionOperativa.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> clearSession(int deviceId) async {
    await _apiClient.delete('/operacion/dispositivos/$deviceId/sesion');
  }
}
