import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api_client.dart';
import '../../auth/auth_provider.dart';
import '../models/asistencia.dart';

final asistenciaServiceProvider = Provider<AsistenciaService>(
  (ref) => AsistenciaService(ref.read(authenticatedApiClientProvider)),
);

class AsistenciaService {
  AsistenciaService(this._apiClient);
  final AuthenticatedApiClient _apiClient;

  Future<List<Asistencia>> getAll() async {
    final response =
        await _apiClient.get('/asistencias') as Map<String, dynamic>;
    return (response['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Asistencia.fromJson)
        .toList();
  }

  Future<Asistencia> getById(int id) async {
    final response =
        await _apiClient.get('/asistencias/$id') as Map<String, dynamic>;
    return Asistencia.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Asistencia> create(Asistencia item) async {
    final response = await _apiClient.post(
      '/asistencias',
      body: item.toJson(),
    ) as Map<String, dynamic>;
    return Asistencia.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Asistencia> update(Asistencia item) async {
    final response = await _apiClient.put(
      '/asistencias/${item.idAsistencia}',
      body: item.toJson(),
    ) as Map<String, dynamic>;
    return Asistencia.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Asistencia> changeStatus(int id, String estado) async {
    final response = await _apiClient.patch(
      '/asistencias/$id/estado',
      body: {'estado': estado},
    ) as Map<String, dynamic>;
    return Asistencia.fromJson(response['data'] as Map<String, dynamic>);
  }
}
