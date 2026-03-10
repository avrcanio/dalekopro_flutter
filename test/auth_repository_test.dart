import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/core/network/api_client.dart';
import 'package:dalekopro_farma_flutter/core/storage/token_storage.dart';
import 'package:dalekopro_farma_flutter/features/auth/data/auth_repository.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    setupMockSecureStorage();
    setupMockGeolocator();
  });
  tearDown(() {
    clearMockGeolocator();
    clearMockSecureStorage();
  });

  test('auth repository maps success and persists token + user', () async {
    final storage = const TokenStorage();
    final client = ApiClient(tokenStorage: storage);

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'token': 'token-1',
                'user': {
                  'id': 12,
                  'username': 'demo',
                  'email': 'demo@example.com',
                  'first_name': 'Demo',
                  'last_name': 'User',
                },
              },
            ),
          );
        },
      ),
    );

    final repo = AuthRepository(client: client, tokenStorage: storage);
    final result = await repo.login(username: 'demo', password: 'pass');

    expect(result.token, 'token-1');
    expect((await storage.readToken()), 'token-1');
    expect((await storage.readUser())?.username, 'demo');
  });

  test('auth repository maps 401', () async {
    final storage = const TokenStorage();
    final client = ApiClient(tokenStorage: storage);

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 401),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    final repo = AuthRepository(client: client, tokenStorage: storage);

    await expectLater(
      () => repo.login(username: 'demo', password: 'bad'),
      throwsA(isA<Exception>()),
    );
  });

  test('auth repository maps 400', () async {
    final storage = const TokenStorage();
    final client = ApiClient(tokenStorage: storage);

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 400),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    final repo = AuthRepository(client: client, tokenStorage: storage);

    await expectLater(
      () => repo.login(username: '', password: ''),
      throwsA(isA<Exception>()),
    );
  });

  test('auth repository maps network timeout', () async {
    final storage = const TokenStorage();
    final client = ApiClient(tokenStorage: storage);

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
            ),
          );
        },
      ),
    );

    final repo = AuthRepository(client: client, tokenStorage: storage);

    await expectLater(
      () => repo.login(username: 'demo', password: 'pass'),
      throwsA(isA<Exception>()),
    );
  });
}
