import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../config/app_environment.dart';
import '../../../services/authenticated_api_client.dart';
import '../models/device_session.dart';

final operacionApiClientProvider = Provider<AuthenticatedApiClient>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return AuthenticatedApiClient(
    client: client,
    baseUrl: AppEnvironment.apiBaseUrl,
    accessToken: () => null,
    onUnauthorized: () async {},
  );
});

final operacionServiceProvider = Provider<OperacionService>(
  (ref) => OperacionService(ref.read(operacionApiClientProvider)),
);

class OperacionService {
  OperacionService(this._apiClient);

  final AuthenticatedApiClient _apiClient;
  static const _storage = FlutterSecureStorage();
  String? _sessionToken;
  int? _deviceId;

  Map<String, String> _headers(int id) {
    return _sessionToken == null || _deviceId != id
        ? {}
        : {'X-Device-Session': _sessionToken!};
  }

  Future<int?> restoreDeviceSession() async {
    _sessionToken = await _storage.read(key: 'operative_session_token');
    _deviceId = int.tryParse(
      await _storage.read(key: 'operative_device_id') ?? '',
    );
    if (_sessionToken == null || _deviceId == null) return null;
    try {
      await getSession(_deviceId!);
      return _deviceId;
    } catch (_) {
      await clearLocalSession();
      return null;
    }
  }

  Future<DispositivoInfo> login(String username, String password) async {
    final response = await _apiClient.post(
      '/operacion/login',
      body: {'usuario': username, 'password': password},
    ) as Map<String, dynamic>;
    final data = response['data'] as Map<String, dynamic>;
    final device = DispositivoInfo.fromJson(
      data['dispositivo'] as Map<String, dynamic>,
    );
    _sessionToken = data['session_token'] as String;
    _deviceId = device.idDispositivo;
    await _storage.write(key: 'operative_session_token', value: _sessionToken);
    await _storage.write(
      key: 'operative_device_id',
      value: '${device.idDispositivo}',
    );
    return device;
  }

  Future<void> logoutDevice(int deviceId) async {
    try {
      await _apiClient.post(
        '/operacion/dispositivos/$deviceId/logout',
        headers: _headers(deviceId),
      );
    } finally {
      await clearLocalSession();
    }
  }

  Future<void> clearLocalSession() async {
    _sessionToken = null;
    _deviceId = null;
    await _storage.delete(key: 'operative_session_token');
    await _storage.delete(key: 'operative_device_id');
  }

  Future<DispositivoInfo> getDeviceById(int deviceId) async {
    final response = await _apiClient.get(
      '/operacion/dispositivos/$deviceId',
    ) as Map<String, dynamic>;
    return DispositivoInfo.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<DispositivoInfo> getDeviceByCodigo(String codigo) async {
    final response = await _apiClient.get(
      '/operacion/dispositivos/codigo/$codigo',
    ) as Map<String, dynamic>;
    return DispositivoInfo.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<List<GuardiaDisponible>> getAvailableGuards(int deviceId) async {
    final response = await _apiClient.get(
      '/operacion/dispositivos/$deviceId/guardias',
      headers: _headers(deviceId),
    ) as Map<String, dynamic>;
    final list = response['data'] as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(GuardiaDisponible.fromJson)
        .toList();
  }

  Future<SesionOperativa> getSession(int deviceId) async {
    final response = await _apiClient.get(
      '/operacion/dispositivos/$deviceId/sesion',
      headers: _headers(deviceId),
    ) as Map<String, dynamic>;
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
    await _apiClient.delete(
      '/operacion/dispositivos/$deviceId/sesion',
      headers: _headers(deviceId),
    );
  }

  Future<void> createAttendance(
    int deviceId, {
    required String latitud,
    required String longitud,
    String? observacion,
  }) async {
    await _apiClient.post(
      '/operacion/dispositivos/$deviceId/asistencias',
      headers: _headers(deviceId),
      body: {
        'latitud': latitud,
        'longitud': longitud,
        'observacion': observacion,
      },
    );
  }

  Future<void> createIncident(
    int deviceId, {
    required String tipo,
    required String descripcion,
    String? photoPath,
  }) async {
    if (photoPath == null) {
      await _apiClient.post(
        '/operacion/dispositivos/$deviceId/novedades',
        headers: _headers(deviceId),
        body: {'tipo': tipo, 'descripcion': descripcion},
      );
    } else {
      await _apiClient.postMultipart(
        '/operacion/dispositivos/$deviceId/novedades-con-foto',
        headers: _headers(deviceId),
        fields: {'tipo': tipo, 'descripcion': descripcion},
        filePath: photoPath,
      );
    }
  }
}
