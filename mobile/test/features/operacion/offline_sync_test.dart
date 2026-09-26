import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/operacion/models/pending_operation.dart';
import 'package:mobile/features/operacion/services/operacion_service.dart';
import 'package:mobile/features/operacion/services/pending_operation_store.dart';
import 'package:mobile/services/authenticated_api_client.dart';

const _operationId = '40000000-0000-4000-8000-000000000005';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('P15-05 offline conserva UUID y sincroniza una sola operacion', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp('pacific-offline-');
    final sentIds = <String>[];
    var offline = false;
    final client = MockClient((request) async {
      if (request.url.path == '/operacion/login') {
        return http.Response(
          jsonEncode({
            'data': {
              'session_token': 'test-device-session',
              'dispositivo': {
                'id_dispositivo': 7,
                'codigo_dispositivo': 'P15-DEVICE',
                'estado': 'activo',
                'id_puesto': 1,
              },
            },
          }),
          200,
        );
      }
      if (offline) throw http.ClientException('offline');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      sentIds.add(body['operation_id'] as String);
      return http.Response('{}', 201);
    });
    final store = PendingOperationStore(rootDirectory: directory);
    final service = OperacionService(
      AuthenticatedApiClient(
        client: client,
        baseUrl: 'http://localhost',
        accessToken: () => null,
        onUnauthorized: () async {},
      ),
      operationStore: store,
      operationIdGenerator: () => _operationId,
      clock: () => DateTime(2026, 9, 25, 10, 30),
    );

    try {
      await service.login('p15', 'test-password');
      offline = true;
      final pending = await service.createAttendance(
        7,
        latitud: '-0.180653',
        longitud: '-78.467834',
      );
      expect(pending.operationId, _operationId);
      expect(pending.status, PendingOperationStatus.pendiente);
      expect(pending.attempts, 1);

      offline = false;
      final results = await service.syncPendingOperations();
      expect(results, hasLength(1));
      expect(results.single.status, PendingOperationStatus.sincronizado);
      expect(results.single.attempts, 2);
      expect(sentIds, [_operationId]);
      expect(await service.pendingOperations(7), isEmpty);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('novedad offline conserva una copia estable de la fotografia', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp('pacific-photo-');
    final source = File('${directory.path}${Platform.pathSeparator}capture.jpg');
    await source.writeAsBytes([0xff, 0xd8, 0xff, 0xd9]);
    var offline = false;
    var incidentRequests = 0;
    final service = OperacionService(
      AuthenticatedApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/operacion/login') {
            return http.Response(
              jsonEncode({
                'data': {
                  'session_token': 'test-device-session',
                  'dispositivo': {
                    'id_dispositivo': 7,
                    'codigo_dispositivo': 'P15-DEVICE',
                    'estado': 'activo',
                    'id_puesto': 1,
                  },
                },
              }),
              200,
            );
          }
          if (offline) throw http.ClientException('offline');
          incidentRequests++;
          return http.Response('{}', 201);
        }),
        baseUrl: 'http://localhost',
        accessToken: () => null,
        onUnauthorized: () async {},
      ),
      operationStore: PendingOperationStore(rootDirectory: directory),
      operationIdGenerator: () => '40000000-0000-4000-8000-000000000006',
    );

    try {
      await service.login('p15', 'test-password');
      offline = true;
      final pending = await service.createIncident(
        7,
        tipo: 'CONTROL',
        descripcion: 'Evidencia offline',
        photoPath: source.path,
      );
      expect(pending.status, PendingOperationStatus.pendiente);
      expect(pending.photoPath, isNot(source.path));
      expect(await File(pending.photoPath!).exists(), isTrue);
      await source.delete();

      offline = false;
      final results = await service.syncPendingOperations();
      expect(results.single.status, PendingOperationStatus.sincronizado);
      expect(incidentRequests, 1);
      expect(await File(pending.photoPath!).exists(), isFalse);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('restauracion sin red conserva la sesion operativa local', () async {
    FlutterSecureStorage.setMockInitialValues({
      'operative_session_token': 'stored-session',
      'operative_device_id': '7',
    });
    final directory = await Directory.systemTemp.createTemp('pacific-restore-');
    var offline = true;
    final service = OperacionService(
      AuthenticatedApiClient(
        client: MockClient((_) async {
          if (offline) throw http.ClientException('offline');
          return http.Response(
            jsonEncode({
              'data': {
                'dispositivo': {
                  'id_dispositivo': 7,
                  'codigo_dispositivo': 'P15-DEVICE',
                  'estado': 'activo',
                  'id_puesto': 1,
                },
                'guardia_identificado': null,
                'estado': 'sin_identificar',
              },
            }),
            200,
          );
        }),
        baseUrl: 'http://localhost',
        accessToken: () => null,
        onUnauthorized: () async {},
      ),
      operationStore: PendingOperationStore(rootDirectory: directory),
    );

    try {
      expect(await service.restoreDeviceSession(), 7);
      offline = false;
      expect(await service.restoreDeviceSession(), 7);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('token operativo invalido elimina la sesion local', () async {
    FlutterSecureStorage.setMockInitialValues({
      'operative_session_token': 'revoked-session',
      'operative_device_id': '7',
    });
    final directory = await Directory.systemTemp.createTemp('pacific-revoked-');
    var unauthorized = true;
    final service = OperacionService(
      AuthenticatedApiClient(
        client: MockClient((_) async {
          if (unauthorized) {
            return http.Response(jsonEncode({'error': 'revocada'}), 401);
          }
          return http.Response('{}', 200);
        }),
        baseUrl: 'http://localhost',
        accessToken: () => null,
        onUnauthorized: () async {},
      ),
      operationStore: PendingOperationStore(rootDirectory: directory),
    );

    try {
      expect(await service.restoreDeviceSession(), isNull);
      unauthorized = false;
      expect(await service.restoreDeviceSession(), isNull);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
