import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api_client.dart';
import '../../auth/auth_provider.dart';
import '../models/novedad.dart';

final novedadServiceProvider = Provider<NovedadService>(
  (ref) => NovedadService(ref.read(authenticatedApiClientProvider)),
);

class NovedadService {
  NovedadService(this._apiClient);
  final AuthenticatedApiClient _apiClient;

  Future<List<Novedad>> getAll() async {
    final response = await _apiClient.get('/novedades') as Map<String, dynamic>;
    return (response['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Novedad.fromJson)
        .toList();
  }

  Future<Novedad> getById(int id) async {
    final response =
        await _apiClient.get('/novedades/$id') as Map<String, dynamic>;
    return Novedad.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Novedad> create(Novedad item) async {
    final response = await _apiClient.post(
      '/novedades',
      body: item.toJson(),
    ) as Map<String, dynamic>;
    return Novedad.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Novedad> update(Novedad item) async {
    final response = await _apiClient.put(
      '/novedades/${item.idNovedad}',
      body: item.toJson(),
    ) as Map<String, dynamic>;
    return Novedad.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Novedad> changeStatus(int id, String estado) async {
    final response = await _apiClient.patch(
      '/novedades/$id/estado',
      body: {'estado': estado},
    ) as Map<String, dynamic>;
    return Novedad.fromJson(response['data'] as Map<String, dynamic>);
  }
}
