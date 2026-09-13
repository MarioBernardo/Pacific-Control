import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/shifts/models/turno.dart';
import 'package:mobile/features/shifts/services/turno_service.dart';
import 'package:mobile/services/authenticated_api_client.dart';

void main() {
  const turnoJson = {
    'id_turno': 8,
    'fecha': '2026-09-13',
    'hora_inicio': '08:00:00',
    'hora_fin': '16:00:00',
    'estado': 'activo',
    'id_empleado': 4,
    'id_puesto': 3,
  };

  TurnoService serviceFor(http.Client client) => TurnoService(
        AuthenticatedApiClient(
          client: client,
          baseUrl: 'http://api.test',
          accessToken: () => 'TEST_TOKEN',
          onUnauthorized: () async {},
        ),
      );

  test('GET list and individual shift preserve dates and relations', () async {
    final service = serviceFor(
      MockClient((request) async {
        final body = request.url.path == '/turnos'
            ? {'data': [turnoJson]}
            : {'data': turnoJson};
        return http.Response(jsonEncode(body), 200);
      }),
    );
    final turno = (await service.getAll()).single;
    expect(turno.fecha, '2026-09-13');
    expect(turno.horaInicio, '08:00:00');
    expect(turno.idEmpleado, 4);
    expect((await service.getById(8)).idPuesto, 3);
  });

  test('POST, PUT and PATCH use the real shift bodies and methods', () async {
    final methods = <String>[];
    final service = serviceFor(
      MockClient((request) async {
        methods.add(request.method);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.method == 'PATCH') {
          expect(body, {'estado': 'inactivo'});
        } else {
          expect(body['fecha'], '2026-09-13');
          expect(body['hora_inicio'], '08:00:00');
          expect(body['hora_fin'], '16:00:00');
          expect(body['id_empleado'], 4);
          expect(body['id_puesto'], 3);
        }
        return http.Response(jsonEncode({'data': turnoJson}), 200);
      }),
    );
    final turno = Turno.fromJson(turnoJson);
    await service.create(turno);
    await service.update(turno);
    await service.changeStatus(8, 'inactivo');
    expect(methods, ['POST', 'PUT', 'PATCH']);
  });

  test('API errors remain typed for the shift service', () async {
    final service = serviceFor(
      MockClient((_) async => http.Response('{"error":"Sin permisos."}', 403)),
    );
    await expectLater(service.getAll(), throwsA(isA<ApiForbiddenException>()));
  });
}
