import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/incidents/models/novedad.dart';
import 'package:mobile/features/incidents/services/novedad_service.dart';
import 'package:mobile/services/authenticated_api_client.dart';

void main() {
  const json = {
    'id_novedad': 1,
    'tipo': 'Incidencia',
    'descripcion': 'Prueba',
    'fecha_hora': '2026-09-13T09:00:00',
    'estado': 'abierta',
    'id_empleado': 2,
    'id_turno': 3,
    'id_dispositivo': 4,
    'evidencia_foto': 'uploads/novedades/test.jpg',
    'guardia': {'nombre_completo': 'TIPANTUÑA TACO DIEGO MARCELO'},
    'puesto': {'nombre_puesto': 'ED. BAVIERA'},
    'turno': {'tipo_turno': '12 HORAS', 'tipo_asignacion': 'FIJO'},
    'dispositivo': {'codigo_dispositivo': 'BAVIERA-01'},
  };
  NovedadService service(http.Client c) => NovedadService(
    AuthenticatedApiClient(
      client: c,
      baseUrl: 'http://test',
      accessToken: () => 'token',
      onUnauthorized: () async {},
    ),
  );
  test('GET transforms novedad and keeps references', () async {
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
    expect(item.idTurno, 3);
    expect(item.guardiaNombre, 'TIPANTUÑA TACO DIEGO MARCELO');
    expect(item.puestoNombre, 'ED. BAVIERA');
    expect(item.evidenciaFoto, isNotNull);
  });
  test('POST PUT PATCH use real payloads', () async {
    final methods = <String>[];
    final s = service(
      MockClient((r) async {
        methods.add(r.method);
        final b = jsonDecode(r.body);
        if (r.method == 'PATCH') {
          expect(b, {'estado': 'cerrada'});
        } else {
          expect(b['id_empleado'], 2);
          expect(b['id_turno'], 3);
        }
        return http.Response(jsonEncode({'data': json}), 200);
      }),
    );
    final item = Novedad.fromJson(json);
    await s.create(item);
    await s.update(item);
    await s.changeStatus(1, 'cerrada');
    expect(methods, ['POST', 'PUT', 'PATCH']);
  });
  test('409 is typed', () async {
    final s = service(
      MockClient((_) async => http.Response('{"error":"Conflicto"}', 409)),
    );
    await expectLater(s.getAll(), throwsA(isA<ApiConflictException>()));
  });
}
