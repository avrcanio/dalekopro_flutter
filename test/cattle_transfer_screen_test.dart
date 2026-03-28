import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/core/network/api_client.dart';
import 'package:dalekopro_farma_flutter/core/storage/token_storage.dart';
import 'package:dalekopro_farma_flutter/features/cattle/data/cattle_repository.dart';
import 'package:dalekopro_farma_flutter/features/cattle_transfer/data/cattle_transfer_repository.dart';
import 'package:dalekopro_farma_flutter/features/cattle_transfer/presentation/cattle_transfer_screen.dart';
import 'package:dalekopro_farma_flutter/features/farms/data/farms_repository.dart';

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

  testWidgets(
    'transfer screen filters destination options and uses Croatian labels',
    (tester) async {
      final client = ApiClient(tokenStorage: const TokenStorage());

      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/gospodarstva/') {
              handler.resolve(
                Response<List<Map<String, dynamic>>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'id': 1,
                      'naziv_gospodarstva': 'OPG A',
                      'naziv_farme': 'Farma A',
                    },
                  ],
                ),
              );
              return;
            }

            if (options.path == '/api/gospodarstva/1/posjedi/') {
              handler.resolve(
                Response<List<Map<String, dynamic>>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {'id': 10, 'parcela_posjed_display': 'Kuća'},
                    {'id': 11, 'parcela_posjed_display': 'Morpolača'},
                    {'id': 12, 'parcela_posjed_display': 'Čista'},
                  ],
                ),
              );
              return;
            }

            if (options.path == '/api/gospodarstva/1/animals/') {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'animals': const []},
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

      await tester.pumpWidget(
        MaterialApp(
          home: CattleTransferScreen(
            farmsRepository: FarmsRepository(client: client),
            cattleRepository: CattleRepository(client: client),
            transferRepository: CattleTransferRepository(client: client),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Premještanje goveda'), findsOneWidget);
      expect(find.text('Polazni posjed'), findsOneWidget);
      expect(find.text('Odredišni posjed'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('cattle-transfer-origin-dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kuća').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('cattle-transfer-destination-dropdown')),
      );
      await tester.pumpAndSettle();

    expect(find.text('Morpolača').last, findsOneWidget);
    expect(find.text('Čista').last, findsOneWidget);
    expect(find.text('Kuća'), findsOneWidget);
    },
  );

  testWidgets('transfer screen groups cattle by uzrast on step 2', (
    tester,
  ) async {
    final client = ApiClient(tokenStorage: const TokenStorage());

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/gospodarstva/') {
            handler.resolve(
              Response<List<Map<String, dynamic>>>(
                requestOptions: options,
                statusCode: 200,
                data: [
                  {
                    'id': 1,
                    'naziv_gospodarstva': 'OPG A',
                    'naziv_farme': 'Farma A',
                  },
                ],
              ),
            );
            return;
          }

          if (options.path == '/api/gospodarstva/1/posjedi/') {
            handler.resolve(
              Response<List<Map<String, dynamic>>>(
                requestOptions: options,
                statusCode: 200,
                data: [
                  {'id': 10, 'parcela_posjed_display': 'Kuća'},
                  {'id': 11, 'parcela_posjed_display': 'Morpolača'},
                ],
              ),
            );
            return;
          }

          if (options.path == '/api/gospodarstva/1/animals/') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'animals': [
                    {
                      'posjed_veza_id': 10,
                      'posjed': {'naziv': 'Kuća'},
                      'govedo': {
                        'id': 77,
                        'zivotni_broj': 'HR000077',
                        'ime': 'Mila',
                        'uzrast': 'Krava',
                        'potomci': [],
                      },
                    },
                    {
                      'posjed_veza_id': 10,
                      'posjed': {'naziv': 'Kuća'},
                      'govedo': {
                        'id': 78,
                        'zivotni_broj': 'HR000078',
                        'ime': 'Bela',
                        'uzrast': 'Junica',
                        'potomci': [],
                      },
                    },
                    {
                      'posjed_veza_id': 11,
                      'posjed': {'naziv': 'Morpolača'},
                      'govedo': {
                        'id': 79,
                        'zivotni_broj': 'HR000079',
                        'ime': 'Lina',
                        'uzrast': 'Bik',
                        'potomci': [],
                      },
                    },
                  ],
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

    await tester.pumpWidget(
      MaterialApp(
        home: CattleTransferScreen(
          farmsRepository: FarmsRepository(client: client),
          cattleRepository: CattleRepository(client: client),
          transferRepository: CattleTransferRepository(client: client),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cattle-transfer-origin-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kuća').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('cattle-transfer-destination-dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morpolača').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('cattle-transfer-continue')),
    );
    await tester.tap(find.byKey(const Key('cattle-transfer-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Goveda na polaznom posjedu (2)'), findsOneWidget);
    expect(
      find.byKey(const Key('cattle-transfer-group-Krava')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('cattle-transfer-group-Junica')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('cattle-transfer-cattle-77')), findsOneWidget);
    expect(find.byKey(const Key('cattle-transfer-cattle-78')), findsOneWidget);
    expect(find.byKey(const Key('cattle-transfer-cattle-79')), findsNothing);
  });

  testWidgets(
    'transfer screen submits transfer and shows Croatian summary labels',
    (tester) async {
      final client = ApiClient(tokenStorage: const TokenStorage());
      var transferCalled = false;

      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/gospodarstva/') {
              handler.resolve(
                Response<List<Map<String, dynamic>>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'id': 1,
                      'naziv_gospodarstva': 'OPG A',
                      'naziv_farme': 'Farma A',
                    },
                  ],
                ),
              );
              return;
            }

            if (options.path == '/api/gospodarstva/1/posjedi/') {
              handler.resolve(
                Response<List<Map<String, dynamic>>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {'id': 10, 'parcela_posjed_display': 'Kuća'},
                    {'id': 11, 'parcela_posjed_display': 'Morpolača'},
                  ],
                ),
              );
              return;
            }

            if (options.path == '/api/gospodarstva/1/animals/') {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'animals': [
                      {
                        'posjed_veza_id': 10,
                        'posjed': {'naziv': 'Kuća'},
                        'govedo': {
                          'id': 77,
                          'zivotni_broj': 'HR000077',
                          'ime': 'Mila',
                          'uzrast': 'Krava',
                          'potomci': [],
                        },
                      },
                      {
                        'posjed_veza_id': 11,
                        'posjed': {'naziv': 'Morpolača'},
                        'govedo': {
                          'id': 88,
                          'zivotni_broj': 'HR000088',
                          'ime': 'Lina',
                          'uzrast': 'Junica',
                          'potomci': [],
                        },
                      },
                    ],
                  },
                ),
              );
              return;
            }

            if (options.path == '/api/goveda/transfer/') {
              transferCalled = true;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'status': 'OK',
                    'gospodarstvo_id': 1,
                    'origin_posjed_id': 10,
                    'destination_posjed_id': 11,
                    'moved_count': 1,
                    'goveda_ids': [77],
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

      await tester.pumpWidget(
        MaterialApp(
          home: CattleTransferScreen(
            farmsRepository: FarmsRepository(client: client),
            cattleRepository: CattleRepository(client: client),
            transferRepository: CattleTransferRepository(client: client),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('cattle-transfer-origin-dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kuća').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('cattle-transfer-destination-dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Morpolača').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cattle-transfer-continue')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cattle-transfer-cattle-77')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cattle-transfer-continue')));
      await tester.pumpAndSettle();

      expect(find.text('Polazni posjed: Kuća'), findsOneWidget);
      expect(find.text('Odredišni posjed: Morpolača'), findsOneWidget);

      await tester.tap(find.text('Premjesti'));
      await tester.pumpAndSettle();

      expect(transferCalled, isTrue);
    },
  );

  testWidgets('transfer screen shows warning when holdings are unavailable', (
    tester,
  ) async {
    final client = ApiClient(tokenStorage: const TokenStorage());

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/gospodarstva/') {
            handler.resolve(
              Response<List<Map<String, dynamic>>>(
                requestOptions: options,
                statusCode: 200,
                data: [
                  {
                    'id': 1,
                    'naziv_gospodarstva': 'OPG A',
                    'naziv_farme': 'Farma A',
                  },
                ],
              ),
            );
            return;
          }

          if (options.path == '/api/gospodarstva/1/posjedi/') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {'unexpected': 'shape'},
              ),
            );
            return;
          }

          if (options.path == '/api/gospodarstva/1/animals/') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {'animals': const []},
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

    await tester.pumpWidget(
      MaterialApp(
        home: CattleTransferScreen(
          farmsRepository: FarmsRepository(client: client),
          cattleRepository: CattleRepository(client: client),
          transferRepository: CattleTransferRepository(client: client),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.textContaining('Nema dostupnih posjeda za odabrano gospodarstvo'),
      findsOneWidget,
    );
    expect(find.text('Nema dostupnih posjeda'), findsWidgets);
  });
}
