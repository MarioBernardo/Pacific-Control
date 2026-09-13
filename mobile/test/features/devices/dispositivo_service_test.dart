import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/devices/models/dispositivo.dart';
import 'package:mobile/features/devices/services/dispositivo_service.dart';
import 'package:mobile/services/authenticated_api_client.dart';

void main() {
  const dispositivoJson = {
    'id_dispositivo': 8,
    'codigo_dispositivo': 'DISP-001',
    'modelo': 'Android',
    'estado': 'activo',
    'id_puesto': 3,
  };

  DispositivoService serviceFor(http.Client client) => DispositivoService(
    AuthenticatedApiClient(
      client: client,
      baseUrl: 'http://api.test',
      accessToken: () => 'TEST_TOKEN',
      onUnauthorized: () async {},
    ),
  );

  test('GET list and individual device preserve id_puesto', () async {
    final service = serviceFor(
      MockClient((request) async {
        final body = request.url.path == '/dispositivos'
            ? {
                'data': [dispositivoJson],
              }
            : {'data': dispositivoJson};
        return http.Response(jsonEncode(body), 200);
      }),
    );
    expect((await service.getAll()).single.idPuesto, 3);
    expect((await service.getById(8)).idDispositivo, 8);
  });

  test('POST, PUT and PATCH send the real device payloads', () async {
    final methods = <String>[];
    final service = serviceFor(
      MockClient((request) async {
        methods.add(request.method);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.method == 'PATCH') {
          expect(body, {'estado': 'inactivo'});
        } else {
          expect(body['codigo_dispositivo'], 'DISP-001');
          expect(body['id_puesto'], 3);
        }
        return http.Response(jsonEncode({'data': dispositivoJson}), 200);
      }),
    );
    final dispositivo = Dispositivo.fromJson(dispositivoJson);
    await service.create(dispositivo);
    await service.update(dispositivo);
    await service.changeStatus(8, 'inactivo');
    expect(methods, ['POST', 'PUT', 'PATCH']);
  });

  test('400, 403, 404 and 409 remain typed API errors', () async {
    for (final entry in <int, Type>{
      400: ApiValidationException,
      403: ApiForbiddenException,
      404: ApiNotFoundException,
      409: ApiConflictException,
    }.entries) {
      final service = serviceFor(
        MockClient(
          (_) async => http.Response('{"error":"Error de prueba"}', entry.key),
        ),
      );
      await expectLater(
        service.getAll(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            entry.key,
          ),
        ),
      );
    }
  });
}
