import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/authenticated_api_client.dart';

void main() {
  AuthenticatedApiClient clientFor(http.Client client, {String? token, Future<void> Function()? onUnauthorized}) => AuthenticatedApiClient(
        client: client,
        baseUrl: 'http://example.test/',
        accessToken: () => token,
        onUnauthorized: onUnauthorized ?? () async {},
      );

  test('GET without token omits Authorization and returns data JSON', () async {
    late http.Request request;
    final client = clientFor(MockClient((value) async {
      request = value;
      return http.Response('{"data":{"id":1}}', 200);
    }));
    expect(await client.get('/items'), {'data': {'id': 1}});
    expect(request.headers.containsKey('authorization'), isFalse);
    expect(request.url.toString(), 'http://example.test/items');
  });

  test('GET with token sends Bearer JWT and supports direct JSON', () async {
    late http.Request request;
    final client = clientFor(MockClient((value) async { request = value; return http.Response('{"status":"ok"}', 200); }), token: 'TEST_TOKEN');
    expect(await client.get('status'), {'status': 'ok'});
    expect(request.headers['authorization'], 'Bearer TEST_TOKEN');
  });

  test('POST encodes JSON, content type and Bearer token', () async {
    late http.Request request;
    final client = clientFor(MockClient((value) async { request = value; return http.Response('{}', 201); }), token: 'TEST_TOKEN');
    await client.post('/items', body: {'name': 'Pacific'});
    expect(request.method, 'POST');
    expect(jsonDecode(request.body), {'name': 'Pacific'});
    expect(request.headers['content-type'], 'application/json');
    expect(request.headers['authorization'], 'Bearer TEST_TOKEN');
  });

  test('PUT, PATCH and DELETE use their HTTP methods', () async {
    final methods = <String>[];
    final client = clientFor(MockClient((request) async { methods.add(request.method); return http.Response('', 204); }));
    await client.put('/item/1', body: {'a': 1});
    await client.patch('/item/1', body: {'a': 2});
    await client.delete('/item/1');
    expect(methods, ['PUT', 'PATCH', 'DELETE']);
  });

  test('400 exposes message and details', () async {
    final client = clientFor(MockClient((_) async => http.Response('{"error":"Datos invalidos","detalles":{"correo":"Requerido"}}', 400)));
    await expectLater(client.get('/items'), throwsA(isA<ApiValidationException>().having((error) => error.statusCode, 'status', 400).having((error) => error.details, 'details', {'correo': 'Requerido'})));
  });

  test('401 invalidates session once and throws unauthorized', () async {
    var calls = 0;
    final client = clientFor(MockClient((_) async => http.Response('{"error":"Token invalido"}', 401)), onUnauthorized: () async { calls++; });
    await expectLater(client.get('/items'), throwsA(isA<ApiUnauthorizedException>()));
    expect(calls, 1);
  });

  test('403 preserves session callback and throws forbidden', () async {
    var calls = 0;
    final client = clientFor(MockClient((_) async => http.Response('{"error":"Sin permisos"}', 403)), onUnauthorized: () async { calls++; });
    await expectLater(client.get('/items'), throwsA(isA<ApiForbiddenException>()));
    expect(calls, 0);
  });

  test('404, 409 and 500 map to API exceptions', () async {
    for (final item in [(404, ApiNotFoundException), (409, ApiConflictException), (500, ApiServerException)]) {
      final client = clientFor(MockClient((_) async => http.Response('{"error":"fallo"}', item.$1)));
      await expectLater(client.get('/items'), throwsA(isA<ApiException>().having((error) => error.statusCode, 'status', item.$1)));
    }
  });

  test('empty successful body returns null and invalid JSON is protocol error', () async {
    final empty = clientFor(MockClient((_) async => http.Response('', 204)));
    expect(await empty.get('/items'), isNull);
    final invalid = clientFor(MockClient((_) async => http.Response('not-json', 200)));
    await expectLater(invalid.get('/items'), throwsA(isA<ApiProtocolException>()));
  });

  test('connection errors map to network exception', () async {
    final client = clientFor(MockClient((_) async => throw http.ClientException('offline')));
    await expectLater(client.get('/items'), throwsA(isA<ApiNetworkException>()));
  });
}
