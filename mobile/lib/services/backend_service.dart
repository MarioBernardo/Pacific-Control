import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';

class BackendService {
  BackendService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> getBackendStatus() async {
    final baseUrl = AppEnvironment.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final response = await _client
        .get(Uri.parse('$baseUrl/'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw BackendRequestException(
        'El backend respondió con HTTP ${response.statusCode}.',
      );
    }

    final responseBody = jsonDecode(response.body);
    if (responseBody is! Map<String, dynamic>) {
      throw const BackendRequestException(
        'La respuesta del backend no es un objeto JSON.',
      );
    }

    return responseBody;
  }
}

class BackendRequestException implements Exception {
  const BackendRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}
