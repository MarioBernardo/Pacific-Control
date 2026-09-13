import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api_client.dart';
import '../../auth/auth_provider.dart';
import '../models/turno.dart';

final turnoServiceProvider = Provider<TurnoService>(
  (ref) => TurnoService(ref.read(authenticatedApiClientProvider)),
);

class TurnoService {
  TurnoService(this._apiClient);

  final AuthenticatedApiClient _apiClient;

  Future<List<Turno>> getAll() async {
    final response = await _apiClient.get('/turnos') as Map<String, dynamic>;
    final data = response['data'] as List<dynamic>;
    return data.cast<Map<String, dynamic>>().map(Turno.fromJson).toList();
  }

  Future<Turno> getById(int turnoId) async {
    final response = await _apiClient.get('/turnos/$turnoId') as Map<String, dynamic>;
    return Turno.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Turno> create(Turno turno) async {
    final response = await _apiClient.post(
      '/turnos',
      body: turno.toJson(),
    ) as Map<String, dynamic>;
    return Turno.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Turno> update(Turno turno) async {
    final response = await _apiClient.put(
      '/turnos/${turno.idTurno}',
      body: turno.toJson(),
    ) as Map<String, dynamic>;
    return Turno.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Turno> changeStatus(int turnoId, String estado) async {
    final response = await _apiClient.patch(
      '/turnos/$turnoId/estado',
      body: {'estado': estado},
    ) as Map<String, dynamic>;
    return Turno.fromJson(response['data'] as Map<String, dynamic>);
  }
}
