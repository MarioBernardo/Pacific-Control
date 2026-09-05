import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException({this.statusCode, required this.message, this.details});
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? details;
  @override
  String toString() => message;
}

class ApiUnauthorizedException extends ApiException {
  const ApiUnauthorizedException({super.message = 'No autenticado.'}) : super(statusCode: 401);
}
class ApiForbiddenException extends ApiException {
  const ApiForbiddenException({super.message = 'Sin permisos.'}) : super(statusCode: 403);
}
class ApiValidationException extends ApiException {
  const ApiValidationException({required super.message, super.details}) : super(statusCode: 400);
}
class ApiNotFoundException extends ApiException {
  const ApiNotFoundException({required super.message}) : super(statusCode: 404);
}
class ApiConflictException extends ApiException {
  const ApiConflictException({required super.message}) : super(statusCode: 409);
}
class ApiServerException extends ApiException {
  const ApiServerException({required super.statusCode, required super.message});
}
class ApiNetworkException extends ApiException {
  const ApiNetworkException() : super(message: 'No se pudo conectar con el servidor.');
}
class ApiProtocolException extends ApiException {
  const ApiProtocolException() : super(message: 'La respuesta del servidor no es valida.');
}

class AuthenticatedApiClient {
  AuthenticatedApiClient({required this.client, required String baseUrl, required this.accessToken, required this.onUnauthorized, this.timeout = const Duration(seconds: 15)})
      : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
  final http.Client client;
  final String _baseUrl;
  final String? Function() accessToken;
  final Future<void> Function() onUnauthorized;
  final Duration timeout;

  Future<dynamic> get(String path, {Map<String, String>? headers}) => _send(path, headers: headers, request: (uri, values, _) => client.get(uri, headers: values));
  Future<dynamic> post(String path, {Object? body, Map<String, String>? headers}) => _send(path, body: body, headers: headers, request: (uri, values, encoded) => client.post(uri, headers: values, body: encoded));
  Future<dynamic> put(String path, {Object? body, Map<String, String>? headers}) => _send(path, body: body, headers: headers, request: (uri, values, encoded) => client.put(uri, headers: values, body: encoded));
  Future<dynamic> patch(String path, {Object? body, Map<String, String>? headers}) => _send(path, body: body, headers: headers, request: (uri, values, encoded) => client.patch(uri, headers: values, body: encoded));
  Future<dynamic> delete(String path, {Object? body, Map<String, String>? headers}) => _send(path, body: body, headers: headers, request: (uri, values, encoded) => client.delete(uri, headers: values, body: encoded));

  Future<dynamic> _send(String path, {Object? body, Map<String, String>? headers, required Future<http.Response> Function(Uri, Map<String, String>, String?) request}) async {
    final values = <String, String>{...?headers};
    final token = accessToken();
    if (token != null && token.isNotEmpty) values['Authorization'] = 'Bearer $token';
    final encoded = body == null ? null : jsonEncode(body);
    if (encoded != null) values.putIfAbsent('Content-Type', () => 'application/json');
    try {
      final response = await request(Uri.parse(_url(path)), values, encoded).timeout(timeout);
      return await _handleResponse(response);
    } on ApiException { rethrow; } on TimeoutException { throw const ApiNetworkException(); } on http.ClientException { throw const ApiNetworkException(); }
  }

  Future<dynamic> _handleResponse(http.Response response) async {
    final parsed = _tryDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (identical(parsed, _invalidJson)) throw const ApiProtocolException();
      return parsed;
    }
    final payload = parsed is Map<String, dynamic> ? parsed : const <String, dynamic>{};
    final message = payload['error']?.toString() ?? 'No fue posible completar la solicitud.';
    final details = payload['detalles'] is Map<String, dynamic> ? payload['detalles'] as Map<String, dynamic> : null;
    if (response.statusCode == 401) {
      try { await onUnauthorized(); } catch (_) {}
      throw ApiUnauthorizedException(message: message);
    }
    if (response.statusCode == 403) throw ApiForbiddenException(message: message);
    if (response.statusCode == 400) throw ApiValidationException(message: message, details: details);
    if (response.statusCode == 404) throw ApiNotFoundException(message: message);
    if (response.statusCode == 409) throw ApiConflictException(message: message);
    if (response.statusCode >= 500) throw ApiServerException(statusCode: response.statusCode, message: message);
    throw ApiException(statusCode: response.statusCode, message: message, details: details);
  }

  String _url(String path) => '$_baseUrl/${path.replaceFirst(RegExp(r'^/+'), '')}';
  dynamic _tryDecode(String body) { if (body.trim().isEmpty) return null; try { return jsonDecode(body); } on FormatException { return _invalidJson; } }
}

final _invalidJson = Object();
