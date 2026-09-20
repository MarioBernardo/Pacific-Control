import '../../../services/authenticated_api_client.dart';
import '../models/administrative_reports.dart';

class AdministrativeReportService {
  const AdministrativeReportService(this._client);
  final AuthenticatedApiClient _client;

  Future<AdministrativeDashboard> dashboard() async {
    final response =
        await _client.get('/reportes/dashboard') as Map<String, dynamic>;
    return AdministrativeDashboard.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  Future<List<PersonnelOnShift>> personnelOnShift() async {
    final response = await _client.get(
      '/reportes/personal-en-turno',
    ) as Map<String, dynamic>;
    return (response['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PersonnelOnShift.fromJson)
        .toList();
  }

  Future<GuardMonthlySummary> monthlySummary(
    int employeeId,
    int month,
    int year,
  ) async {
    final response = await _client.get(
      '/reportes/guardias/$employeeId/resumen-mensual?mes=$month&anio=$year',
    ) as Map<String, dynamic>;
    return GuardMonthlySummary.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }
}
