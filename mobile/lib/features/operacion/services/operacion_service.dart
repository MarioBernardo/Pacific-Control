import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../config/app_environment.dart';
import '../../../services/authenticated_api_client.dart';
import '../models/device_session.dart';
import '../models/pending_operation.dart';
import 'pending_operation_store.dart';

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
  OperacionService(
    this._apiClient, {
    FlutterSecureStorage? storage,
    PendingOperationStore? operationStore,
    DateTime Function()? clock,
    String Function()? operationIdGenerator,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _operationStore = operationStore ?? PendingOperationStore(),
       _clock = clock ?? DateTime.now,
       _operationIdGenerator = operationIdGenerator ?? _uuidV4;

  final AuthenticatedApiClient _apiClient;
  final FlutterSecureStorage _storage;
  final PendingOperationStore _operationStore;
  final DateTime Function() _clock;
  final String Function() _operationIdGenerator;
  String? _sessionToken;
  int? _deviceId;
  bool _syncing = false;

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
      await syncPendingOperations();
      return _deviceId;
    } on ApiNetworkException {
      return _deviceId;
    } on ApiUnauthorizedException {
      await clearLocalSession();
      return null;
    } on ApiNotFoundException {
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
    await syncPendingOperations();
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
      headers: _headers(deviceId),
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

  Future<PendingOperation> createAttendance(
    int deviceId, {
    required String latitud,
    required String longitud,
    String? observacion,
  }) async {
    final localDate = _clock();
    final operation = PendingOperation(
      operationId: _operationIdGenerator(),
      type: PendingOperationType.asistencia,
      deviceId: deviceId,
      payload: {
        'fecha_hora': localDate.toIso8601String(),
        'latitud': latitud,
        'longitud': longitud,
        'observacion': observacion,
      },
      localDate: localDate,
      status: PendingOperationStatus.pendiente,
      attempts: 0,
    );
    final queued = await _operationStore.enqueue(operation);
    return _sendOperation(queued);
  }

  Future<PendingOperation> createIncident(
    int deviceId, {
    required String tipo,
    required String descripcion,
    String? photoPath,
  }) async {
    final localDate = _clock();
    final operation = PendingOperation(
      operationId: _operationIdGenerator(),
      type: PendingOperationType.novedad,
      deviceId: deviceId,
      payload: {
        'fecha_hora': localDate.toIso8601String(),
        'tipo': tipo,
        'descripcion': descripcion,
      },
      localDate: localDate,
      status: PendingOperationStatus.pendiente,
      attempts: 0,
    );
    final queued = await _operationStore.enqueue(
      operation,
      sourcePhotoPath: photoPath,
    );
    return _sendOperation(queued);
  }

  Future<List<PendingOperation>> pendingOperations([int? deviceId]) async {
    final all = await _operationStore.readAll();
    return all
        .where(
          (item) =>
              item.needsSync &&
              (deviceId == null || item.deviceId == deviceId),
        )
        .toList();
  }

  Future<List<PendingOperation>> syncPendingOperations() async {
    if (_syncing || _sessionToken == null || _deviceId == null) return [];
    _syncing = true;
    try {
      final pending = await pendingOperations(_deviceId);
      final results = <PendingOperation>[];
      for (final operation in pending) {
        results.add(await _sendOperation(operation));
      }
      return results;
    } finally {
      _syncing = false;
    }
  }

  Future<PendingOperation> _sendOperation(PendingOperation operation) async {
    var current = await _operationStore.update(
      operation.copyWith(
        status: PendingOperationStatus.enviando,
        attempts: operation.attempts + 1,
        clearLastError: true,
      ),
    );
    try {
      final body = {...current.payload, 'operation_id': current.operationId};
      if (current.type == PendingOperationType.asistencia) {
        await _apiClient.post(
          '/operacion/dispositivos/${current.deviceId}/asistencias',
          headers: _headers(current.deviceId),
          body: body,
        );
      } else if (current.photoPath == null) {
        await _apiClient.post(
          '/operacion/dispositivos/${current.deviceId}/novedades',
          headers: _headers(current.deviceId),
          body: body,
        );
      } else {
        await _apiClient.postMultipart(
          '/operacion/dispositivos/${current.deviceId}/novedades-con-foto',
          headers: _headers(current.deviceId),
          fields: body.map(
            (key, value) => MapEntry(key, value?.toString() ?? ''),
          ),
          filePath: current.photoPath,
        );
      }
      current = await _operationStore.update(
        current.copyWith(
          status: PendingOperationStatus.sincronizado,
          clearLastError: true,
        ),
      );
      if (current.photoPath != null) {
        try {
          await File(current.photoPath!).delete();
        } on FileSystemException {
          // The backend record is already synchronized; cleanup can be retried later.
        }
      }
      return current;
    } on ApiNetworkException catch (error) {
      return _operationStore.update(
        current.copyWith(
          status: PendingOperationStatus.pendiente,
          lastError: error.message,
        ),
      );
    } on ApiException catch (error) {
      return _operationStore.update(
        current.copyWith(
          status: PendingOperationStatus.error,
          lastError: error.message,
        ),
      );
    } catch (error) {
      return _operationStore.update(
        current.copyWith(
          status: PendingOperationStatus.error,
          lastError: error.toString(),
        ),
      );
    }
  }

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
