import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/employees/models/empleado.dart';
import 'package:mobile/features/employees/services/empleado_service.dart';
import 'package:mobile/services/authenticated_api_client.dart';

void main() {
  const employeeJson = {
    'id_empleado': 7, 'cedula': '1234567890', 'nombres': 'Ana',
    'apellidos': 'Perez', 'correo': 'ana@test.com', 'telefono': '0999999999',
    'cargo': 'Guardia', 'estado': true,
  };
  EmpleadoService serviceFor(
    http.Client client, {
    Future<void> Function()? logout,
  }) => EmpleadoService(
    AuthenticatedApiClient(
      client: client,
      baseUrl: 'http://api.test',
      accessToken: () => 'TEST_TOKEN',
      onUnauthorized: logout ?? () async {},
    ),
  );

  test('list and get by id transform employee JSON', () async {
    final service = serviceFor(
      MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path == '/empleados'
                ? {'data': [employeeJson]}
                : {'data': employeeJson},
          ),
          200,
        ),
      ),
    );
    expect((await service.getAll()).single.nombres, 'Ana');
    expect((await service.getById(7)).idEmpleado, 7);
  });

  test('create sends expected JSON and update uses PUT while status uses PATCH', () async {
    final methods = <String>[];
    final service = serviceFor(
      MockClient((request) async {
        methods.add(request.method);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.method == 'PATCH') {
          expect(body, {'estado': false});
        } else {
          expect(body, containsPair('cedula', '1234567890'));
        }
        return http.Response(jsonEncode({'data': employeeJson}), 200);
      }),
    );
    final employee = Empleado.fromJson(employeeJson);
    await service.create(employee);
    await service.update(employee);
    await service.changeStatus(7, false);
    expect(methods, ['POST', 'PUT', 'PATCH']);
  });

  test('400, 401 and 403 propagate typed API errors', () async {
    for (final code in [400, 401, 403]) {
      var logoutCalls = 0;
      final service = serviceFor(
        MockClient((_) async => http.Response('{"error":"error"}', code)),
        logout: () async => logoutCalls++,
      );

      await expectLater(
        service.getAll(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            code,
          ),
        ),
      );
      expect(logoutCalls, code == 401 ? 1 : 0);
    }
  });
}
