import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/attendance/models/asistencia.dart';
import 'package:mobile/features/attendance/services/asistencia_service.dart';
import 'package:mobile/services/authenticated_api_client.dart';

void main() {
  const json = {
    'id_asistencia': 1,
    'fecha_hora': '2026-09-13T08:00:00',
    'latitud': '-0.18',
    'longitud': '-78.48',
    'foto': null,
    'observacion': 'Ingreso',
    'estado': 'registrada',
    'id_empleado': 2,
    'id_turno': 3,
    'id_dispositivo': 4,
  };
  AsistenciaService service(http.Client c) => AsistenciaService(
    AuthenticatedApiClient(
      client: c,
      baseUrl: 'http://test',
      accessToken: () => 'token',
      onUnauthorized: () async {},
    ),
  );
  test('GET preserves relations and coordinates', () async {
    final s = service(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': [json],
          }),
          200,
        ),
      ),
    );
    final item = (await s.getAll()).single;
    expect(item.idEmpleado, 2);
    expect(item.idDispositivo, 4);
    expect(item.latitud, '-0.18');
  });
  test('POST PUT PATCH use real payloads', () async {
    final methods = <String>[];
    final s = service(
      MockClient((r) async {
        methods.add(r.method);
        final b = jsonDecode(r.body);
        if (r.method == 'PATCH') {
          expect(b, {'estado': 'validada'});
        } else {
          expect(b['id_turno'], 3);
          expect(b['id_dispositivo'], 4);
        }
        return http.Response(jsonEncode({'data': json}), 200);
      }),
    );
    final item = Asistencia.fromJson(json);
    await s.create(item);
    await s.update(item);
    await s.changeStatus(1, 'validada');
    expect(methods, ['POST', 'PUT', 'PATCH']);
  });
  test('403 is typed', () async {
    final s = service(
      MockClient((_) async => http.Response('{"error":"Sin permisos"}', 403)),
    );
    await expectLater(s.getAll(), throwsA(isA<ApiForbiddenException>()));
  });
}
