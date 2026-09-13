import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/positions/models/puesto.dart';
import 'package:mobile/features/positions/services/puesto_service.dart';
import 'package:mobile/services/authenticated_api_client.dart';

void main() {
  const puestoJson = {
    'id_puesto': 4,
    'nombre_puesto': 'Garita Norte',
    'direccion': 'Av. Principal 100',
    'estado': 'activo',
  };

  PuestoService serviceFor(http.Client client) => PuestoService(
    AuthenticatedApiClient(
      client: client,
      baseUrl: 'http://api.test',
      accessToken: () => 'TEST_TOKEN',
      onUnauthorized: () async {},
    ),
  );

  test('list transforms puesto JSON', () async {
    final service = serviceFor(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': [puestoJson],
          }),
          200,
        ),
      ),
    );
    final puesto = (await service.getAll()).single;
    expect(puesto.idPuesto, 4);
    expect(puesto.nombrePuesto, 'Garita Norte');
  });

  test(
    'create, update and status use the expected methods and payloads',
    () async {
      final methods = <String>[];
      final service = serviceFor(
        MockClient((request) async {
          methods.add(request.method);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.method == 'PATCH') {
            expect(body, {'estado': 'inactivo'});
          } else {
            expect(body['nombre_puesto'], 'Garita Norte');
          }
          return http.Response(jsonEncode({'data': puestoJson}), 200);
        }),
      );
      final puesto = Puesto.fromJson(puestoJson);
      await service.create(puesto);
      await service.update(puesto);
      await service.changeStatus(4, 'inactivo');
      expect(methods, ['POST', 'PUT', 'PATCH']);
    },
  );

  test('API errors remain typed for the feature service', () async {
    final service = serviceFor(
      MockClient((_) async => http.Response('{"error":"Sin permisos."}', 403)),
    );
    await expectLater(service.getAll(), throwsA(isA<ApiForbiddenException>()));
  });
}
