import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/core/network/api_client.dart';
import 'package:dalekopro_farma_flutter/core/storage/token_storage.dart';
import 'package:dalekopro_farma_flutter/features/cattle_transfer/data/cattle_transfer_repository.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(setupMockSecureStorage);
  tearDown(clearMockSecureStorage);

  test('fetch holdings maps payload', () async {
    final client = ApiClient(tokenStorage: const TokenStorage());

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/gospodarstva/5/posjedi/') {
            handler.resolve(
              Response<List<Map<String, dynamic>>>(
                requestOptions: options,
                statusCode: 200,
                data: [
                  {
                    'id': 11,
                    'gospodarstvo_naziv': 'OPG Horvat',
                    'parcela_posjed_display': 'Pašnjak Sjever',
                    'aktivno': true,
                  },
                  {
                    'id': 12,
                    'gospodarstvo_naziv': 'OPG Horvat',
                    'parcela_posjed_display': 'Pašnjak Jug',
                    'aktivno': true,
                  },
                ],
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

    final repo = CattleTransferRepository(client: client);
    final holdings = await repo.fetchHoldings(5);

    expect(holdings, hasLength(2));
    expect(holdings.first.id, 11);
    expect(holdings.first.label, 'Pašnjak Sjever');
  });

  test('fetch holdings maps nested backend payload envelope', () async {
    final client = ApiClient(tokenStorage: const TokenStorage());

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/gospodarstva/5/posjedi/') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'gospodarstvo_posjedi': [
                      {
                        'posjed': {
                          'id': 21,
                          'parcela_posjed_display': 'Objekt 1',
                        },
                      },
                      {'posjed_id': 22, 'parcela_posjed_display': 'Objekt 2'},
                    ],
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

    final repo = CattleTransferRepository(client: client);
    final holdings = await repo.fetchHoldings(5);

    expect(holdings, hasLength(2));
    expect(holdings[0].id, 21);
    expect(holdings[0].label, 'Objekt 1');
    expect(holdings[1].id, 22);
    expect(holdings[1].label, 'Objekt 2');
  });

  test('fetch holdings returns empty list for unrecognized payload', () async {
    final client = ApiClient(tokenStorage: const TokenStorage());

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/gospodarstva/5/posjedi/') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {'unexpected': 'shape'},
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

    final repo = CattleTransferRepository(client: client);
    final holdings = await repo.fetchHoldings(5);

    expect(holdings, isEmpty);
  });

  test('transfer repository success', () async {
    final client = ApiClient(tokenStorage: const TokenStorage());

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/api/goveda/transfer/');
          expect(options.method, 'POST');
          expect(options.data, {
            'gospodarstvo_id': 5,
            'origin_posjed_id': 11,
            'destination_posjed_id': 12,
            'goveda_ids': [77, 81],
          });

          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'OK',
                'gospodarstvo_id': 5,
                'origin_posjed_id': 11,
                'destination_posjed_id': 12,
                'moved_count': 2,
                'goveda_ids': [77, 81],
              },
            ),
          );
        },
      ),
    );

    final repo = CattleTransferRepository(client: client);
    final result = await repo.transferCattle(
      farmId: 5,
      originId: 11,
      destinationId: 12,
      cattleIds: const [77, 81],
    );

    expect(result.status, 'OK');
    expect(result.movedCount, 2);
    expect(result.govedaIds, [77, 81]);
  });

  test('transfer repository maps 403', () async {
    final client = ApiClient(tokenStorage: const TokenStorage());

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 403),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    final repo = CattleTransferRepository(client: client);

    await expectLater(
      () => repo.transferCattle(
        farmId: 5,
        originId: 11,
        destinationId: 12,
        cattleIds: const [77],
      ),
      throwsA(isA<Exception>()),
    );
  });
}
