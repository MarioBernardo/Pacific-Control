import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/attendance/services/administrative_report_service.dart';
import 'package:mobile/services/authenticated_api_client.dart';

AdministrativeReportService serviceFor(
  Future<http.Response> Function(http.Request) handler,
) => AdministrativeReportService(
  AuthenticatedApiClient(
    client: MockClient(handler),
    baseUrl: 'http://localhost',
    accessToken: () => 'jwt',
    onUnauthorized: () async {},
  ),
);

void main() {
  test('dashboard transforma indicadores y personal real', () async {
    final service = serviceFor((request) async {
      expect(request.url.path, '/reportes/dashboard');
      return http.Response(
        '{"data":{"guardias_en_turno":1,"asistencias_hoy":2,"novedades_abiertas":3,"puestos_con_personal":1,"personal_en_turno":[{"id_empleado":17,"guardia":"TIPANTUÑA TACO DIEGO MARCELO","puesto":"ED. BAVIERA","tipo_turno":"12 HORAS","fecha_hora":"2026-09-20T07:03:00","finalizacion_estimada":"2026-09-20T19:03:00","estado":"registrada"}]}}',
        200,
      );
    });

    final dashboard = await service.dashboard();
    expect(dashboard.guardsOnShift, 1);
    expect(dashboard.personnel.single.guard, 'TIPANTUÑA TACO DIEGO MARCELO');
    expect(dashboard.personnel.single.shiftType, '12 HORAS');
  });

  test('resumen mensual usa mes, anio y horas derivadas del backend', () async {
    final service = serviceFor((request) async {
      expect(request.url.queryParameters, {'mes': '9', 'anio': '2026'});
      return http.Response(
        '{"data":{"id_empleado":17,"guardia":"Diego","mes":9,"anio":2026,"total_turnos":2,"turnos_12_horas":1,"turnos_24_horas":1,"horas_derivadas":36,"asistencias":2,"puestos":["ED. BAVIERA"],"novedades":1,"historial":[]}}',
        200,
      );
    });

    final summary = await service.monthlySummary(17, 9, 2026);
    expect(summary.totalShifts, 2);
    expect(summary.derivedHours, 36);
    expect(summary.positions, ['ED. BAVIERA']);
  });
}
