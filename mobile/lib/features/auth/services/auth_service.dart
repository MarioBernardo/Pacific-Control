import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../config/app_environment.dart';
import 'auth_session.dart';

class AuthService {
  AuthService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'pacific_control.auth_session';
  static const _storageTimeout = Duration(seconds: 5);

  final http.Client _client;
  final FlutterSecureStorage _storage;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final baseUrl = AppEnvironment.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');

    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'correo': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final responseJson = _decodeObject(response.body);
      if (response.statusCode != 200) {
        throw AuthException(
          responseJson?['error']?.toString() ??
              'No fue posible iniciar sesión. Inténtalo nuevamente.',
        );
      }

      final data = responseJson?['data'];
      if (data is! Map<String, dynamic>) {
        throw const AuthException('La respuesta de autenticación no es válida.');
      }

      final session = AuthSession.fromJson(data);
      await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
      return session;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException('La conexión tardó demasiado. Verifica el backend.');
    } on FormatException {
      throw const AuthException('La respuesta de autenticación no es válida.');
    } catch (_) {
      throw const AuthException('No se pudo conectar con el servidor.');
    }
  }

  Future<AuthSession?> restoreSession() async {
    final value = await _storage
        .read(key: _sessionKey)
        .timeout(_storageTimeout);
    if (value == null) {
      return null;
    }
    final decoded = _decodeObject(value);
    if (decoded == null) {
      await logout();
      return null;
    }
    final session = AuthSession.fromJson(decoded);
    if (_isExpired(session.accessToken)) {
      await logout();
      return null;
    }
    return session;
  }

  Future<void> logout() => _storage.delete(key: _sessionKey).timeout(_storageTimeout);

  Map<String, dynamic>? _decodeObject(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  bool _isExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final exp = _decodeObject(payload)?['exp'];
      return exp is! num ||
          DateTime.fromMillisecondsSinceEpoch(
            exp.toInt() * 1000,
            isUtc: true,
          ).isBefore(DateTime.now().toUtc());
    } catch (_) {
      return true;
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}
