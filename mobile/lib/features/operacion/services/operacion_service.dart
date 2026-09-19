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
  final Map<int, String> _tokens = {};

  Map<String, String> _headers(int id) {
    final token = _tokens[id];
    return token == null ? {} : {'X-Device-Token': token};
  }

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

  Future<DispositivoInfo> activateDevice(String codigo, String token) async {
    final device = await getDeviceByCodigo(codigo);
    _tokens[device.idDispositivo] = token;
    await getSession(device.idDispositivo);
    return device;
  }

  Future<List<GuardiaDisponible>> getAvailableGuards(int deviceId) async {
    final response =
        await _apiClient.get('/operacion/dispositivos/$deviceId/guardias', headers: _headers(deviceId))
            as Map<String, dynamic>;
    final list = response['data'] as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(GuardiaDisponible.fromJson)
        .toList();
  }

  Future<SesionOperativa> getSession(int deviceId) async {
    final response =
        await _apiClient.get('/operacion/dispositivos/$deviceId/sesion', headers: _headers(deviceId))
            as Map<String, dynamic>;
    return SesionOperativa.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<SesionOperativa> identifyGuard(
    int deviceId,
    int empleadoId,
    String tipoTurno,
  ) async {
    final response = await _apiClient.post(
      '/operacion/dispositivos/$deviceId/sesion/identificar',
      headers: _headers(deviceId),
      body: {'id_empleado': empleadoId, 'tipo_turno': tipoTurno},
    ) as Map<String, dynamic>;
    return SesionOperativa.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<void> clearSession(int deviceId) async {
    await _apiClient.delete('/operacion/dispositivos/$deviceId/sesion', headers: _headers(deviceId));
  }


  Future<void> createAttendance(int deviceId, {required String latitud, required String longitud, String? observacion}) async {
    await _apiClient.post('/operacion/dispositivos/$deviceId/asistencias', headers: _headers(deviceId), body: {'latitud': latitud, 'longitud': longitud, 'observacion': observacion});
  }

  Future<void> createIncident(int deviceId, {required String tipo, required String descripcion}) async {
    await _apiClient.post('/operacion/dispositivos/$deviceId/novedades', headers: _headers(deviceId), body: {'tipo': tipo, 'descripcion': descripcion});
  }
}
