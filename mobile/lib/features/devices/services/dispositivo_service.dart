import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api_client.dart';
import '../../auth/auth_provider.dart';
import '../models/dispositivo.dart';

final dispositivoServiceProvider = Provider<DispositivoService>(
  (ref) => DispositivoService(ref.read(authenticatedApiClientProvider)),
);

class DispositivoService {
  DispositivoService(this._apiClient);

  final AuthenticatedApiClient _apiClient;

  Future<List<Dispositivo>> getAll() async {
    final response = await _apiClient.get('/dispositivos') as Map<String, dynamic>;
    final data = response['data'] as List<dynamic>;
    return data
        .cast<Map<String, dynamic>>()
        .map(Dispositivo.fromJson)
        .toList();
  }

  Future<Dispositivo> getById(int dispositivoId) async {
    final response = await _apiClient.get('/dispositivos/$dispositivoId') as Map<String, dynamic>;
    return Dispositivo.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Dispositivo> create(Dispositivo dispositivo) async {
    final response = await _apiClient.post(
      '/dispositivos',
      body: dispositivo.toJson(),
    ) as Map<String, dynamic>;
    return Dispositivo.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Dispositivo> update(Dispositivo dispositivo) async {
    final response = await _apiClient.put(
      '/dispositivos/${dispositivo.idDispositivo}',
      body: dispositivo.toJson(),
    ) as Map<String, dynamic>;
    return Dispositivo.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Dispositivo> changeStatus(int dispositivoId, String estado) async {
    final response = await _apiClient.patch(
      '/dispositivos/$dispositivoId/estado',
      body: {'estado': estado},
    ) as Map<String, dynamic>;
    return Dispositivo.fromJson(response['data'] as Map<String, dynamic>);
  }
}