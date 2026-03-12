import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/core/network/api_client.dart';
import 'package:dalekopro_farma_flutter/core/storage/token_storage.dart';
import 'package:dalekopro_farma_flutter/features/cattle/data/cattle_repository.dart';

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

  test('fetchCattleById maps detail payload', () async {
    final client = ApiClient(tokenStorage: const TokenStorage());

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/goveda/goveda/114/') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 114,
                  'zivotni_broj': 'HR 1201164650',
                  'ime': 'BELA B126',
                  'majka': {
                    'id': 113,
                    'zivotni_broj': 'HR 5200508080',
                    'ime': 'BIBA B126',
                  },
                  'otac': {
                    'id': 3,
                    'hb_broj': '87000000080',
                    'ime': 'NIKO LB3',
                  },
                },
              ),
            );
            return;
          }

          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.unknown,
            ),
          );
        },
      ),
    );

    final repo = CattleRepository(client: client);
    final cattle = await repo.fetchCattleById(114);

    expect(cattle.id, 114);
    expect(cattle.zivotniBroj, 'HR 1201164650');
    expect(cattle.majkaRef?.id, 113);
    expect(cattle.otacRef?.broj, '87000000080');
  });

  test('fetchCattleById throws on invalid payload', () async {
    final client = ApiClient(tokenStorage: const TokenStorage());

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/goveda/goveda/114/') {
            handler.resolve(
              Response<List<dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const [],
              ),
            );
            return;
          }

          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.unknown,
            ),
          );
        },
      ),
    );

    final repo = CattleRepository(client: client);
    await expectLater(
      () => repo.fetchCattleById(114),
      throwsA(isA<StateError>()),
    );
  });
}
