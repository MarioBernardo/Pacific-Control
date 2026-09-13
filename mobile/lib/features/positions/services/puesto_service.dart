import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api_client.dart';
import '../../auth/auth_provider.dart';
import '../models/puesto.dart';

final puestoServiceProvider = Provider<PuestoService>(
  (ref) => PuestoService(ref.read(authenticatedApiClientProvider)),
);

class PuestoService {
  PuestoService(this._apiClient);

  final AuthenticatedApiClient _apiClient;

  Future<List<Puesto>> getAll() async {
    final response = await _apiClient.get('/puestos') as Map<String, dynamic>;
    final data = response['data'] as List<dynamic>;
    return data
        .cast<Map<String, dynamic>>()
        .map(Puesto.fromJson)
        .toList();
  }

  Future<Puesto> create(Puesto puesto) async {
    final response = await _apiClient.post(
      '/puestos',
      body: puesto.toJson(),
    ) as Map<String, dynamic>;
    return Puesto.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Puesto> update(Puesto puesto) async {
    final response = await _apiClient.put(
      '/puestos/${puesto.idPuesto}',
      body: puesto.toJson(),
    ) as Map<String, dynamic>;
    return Puesto.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Puesto> changeStatus(int puestoId, String estado) async {
    final response = await _apiClient.patch(
      '/puestos/$puestoId/estado',
      body: {'estado': estado},
    ) as Map<String, dynamic>;
    return Puesto.fromJson(response['data'] as Map<String, dynamic>);
  }
}
