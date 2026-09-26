import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/operacion/services/operacion_service.dart';
import 'package:mobile/features/operacion/services/pending_operation_store.dart';
import 'package:mobile/services/authenticated_api_client.dart';

void main() {
  test('novedad sin fotografia usa JSON y conserva datos', () async {
    late http.Request captured;
    final directory = await Directory.systemTemp.createTemp('pacific-test-');
    final service = OperacionService(
      AuthenticatedApiClient(
        client: MockClient((request) async {
          captured = request;
          return http.Response('{}', 201);
        }),
        baseUrl: 'http://localhost',
        accessToken: () => null,
        onUnauthorized: () async {},
      ),
      operationStore: PendingOperationStore(rootDirectory: directory),
    );

    try {
      await service.createIncident(
        7,
        tipo: 'INCIDENCIA',
        descripcion: 'Prueba sin foto',
      );
    } finally {
      await directory.delete(recursive: true);
    }

    expect(captured.url.path, '/operacion/dispositivos/7/novedades');
    expect(captured.body, contains('Prueba sin foto'));
  });

  test('novedad con fotografia usa multipart', () async {
    late http.BaseRequest captured;
    final directory = await Directory.systemTemp.createTemp('pacific-test-');
    final service = OperacionService(
      AuthenticatedApiClient(
        client: MockClient((request) async {
          captured = request;
          return http.Response('{}', 201);
        }),
        baseUrl: 'http://localhost',
        accessToken: () => null,
        onUnauthorized: () async {},
      ),
      operationStore: PendingOperationStore(rootDirectory: directory),
    );
    final photo = File('${directory.path}${Platform.pathSeparator}foto.jpg');
    await photo.writeAsBytes([0xff, 0xd8, 0xff, 0xd9]);

    try {
      await service.createIncident(
        7,
        tipo: 'INCIDENCIA',
        descripcion: 'Prueba con foto',
        photoPath: photo.path,
      );
    } finally {
      await directory.delete(recursive: true);
    }

    expect(captured.url.path, '/operacion/dispositivos/7/novedades-con-foto');
    expect(
      captured.headers['content-type'],
      startsWith('multipart/form-data;'),
    );
    final body = String.fromCharCodes((captured as http.Request).bodyBytes);
    expect(body, contains('Prueba con foto'));
    expect(body, contains('.jpg'));
  });
}
