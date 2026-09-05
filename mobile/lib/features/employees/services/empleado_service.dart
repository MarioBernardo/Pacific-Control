import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/authenticated_api_client.dart';
import '../../auth/auth_provider.dart';
import '../models/empleado.dart';

final empleadoServiceProvider = Provider<EmpleadoService>(
  (ref) => EmpleadoService(ref.read(authenticatedApiClientProvider)),
);

class EmpleadoService {
  EmpleadoService(this._apiClient);

  final AuthenticatedApiClient _apiClient;

  Future<List<Empleado>> getAll() async {
    final response = await _apiClient.get('/empleados');
    final data = (response as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .cast<Map<String, dynamic>>()
        .map(Empleado.fromJson)
        .toList();
  }

  Future<Empleado> getById(int empleadoId) async {
    final response = await _apiClient.get('/empleados/$empleadoId');
    return Empleado.fromJson((response as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<Empleado> create(Empleado empleado) async {
    final response = await _apiClient.post('/empleados', body: empleado.toJson());
    return Empleado.fromJson((response as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<Empleado> update(Empleado empleado) async {
    final response = await _apiClient.put('/empleados/${empleado.idEmpleado}', body: empleado.toJson());
    return Empleado.fromJson((response as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<Empleado> changeStatus(int empleadoId, bool estado) async {
    final response = await _apiClient.patch('/empleados/$empleadoId/estado', body: {'estado': estado});
    return Empleado.fromJson((response as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }
}
