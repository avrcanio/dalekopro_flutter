import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/core/network/api_client.dart';
import 'package:dalekopro_farma_flutter/core/storage/token_storage.dart';
import 'package:dalekopro_farma_flutter/features/auth/data/auth_repository.dart';
import 'package:dalekopro_farma_flutter/features/auth/presentation/login_screen.dart';
import 'package:dalekopro_farma_flutter/features/cattle/data/cattle_repository.dart';
import 'package:dalekopro_farma_flutter/features/cattle/models/cattle.dart';
import 'package:dalekopro_farma_flutter/features/cattle/presentation/cattle_list_screen.dart';
import 'package:dalekopro_farma_flutter/features/dashboard/presentation/dashboard_screen.dart';
import 'package:dalekopro_farma_flutter/features/farms/data/farms_repository.dart';
import 'package:dalekopro_farma_flutter/features/upload/data/upload_repository.dart';
import 'package:dalekopro_farma_flutter/features/upload/presentation/upload_screen.dart';

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

  testWidgets('login validation and backend error state', (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(repository: repo, onLogin: (_) {}),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
    await tester.pump();

    expect(find.text('Unesi korisnicko ime'), findsOneWidget);
    expect(find.text('Unesi lozinku'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'demo');
    await tester.enterText(find.byType(TextFormField).last, 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Neispravno korisnicko ime ili lozinka'),
      findsOneWidget,
    );
  });

  testWidgets('cattle list shows empty state', (tester) async {
    final storage = const TokenStorage();
    final client = ApiClient(tokenStorage: storage);

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

          if (options.path == '/api/gospodarstva/1/animals/') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {'animals': []},
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
        home: CattleListScreen(
          farmsRepository: FarmsRepository(client: client),
          cattleRepository: CattleRepository(client: client),
          uploadRepository: UploadRepository(client: client),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Nema aktivnih goveda'), findsOneWidget);
  });

  testWidgets('upload screen validates required image before submit', (
    tester,
  ) async {
    final storage = const TokenStorage();
    final client = ApiClient(tokenStorage: storage);

    final uploadRepo = UploadRepository(client: client);
    final cattle = [
      Cattle(
        id: 1,
        zivotniBroj: 'HR123',
        ime: 'Mila',
        spol: 'Z',
        datumTelenja: '2020-05-01',
        uzrast: '',
        majka: '',
        otac: '',
        imageUrl: '',
        potomci: const [],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: UploadScreen(
          cattle: cattle,
          repository: uploadRepo,
          storage: storage,
        ),
      ),
    );

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Odaberi i obradi sliku prije slanja'),
      findsOneWidget,
    );
  });

  testWidgets(
    'dashboard renders dropdown and navigates to cattle list',
    (tester) async {
      final storage = const TokenStorage();
      final client = ApiClient(tokenStorage: storage);

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

            if (options.path == '/api/gospodarstva/1/animals/') {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'animals': [
                      {
                        'govedo': {
                          'id': 1,
                          'zivotni_broj': 'HR00001234',
                          'ime': 'Mila',
                          'spol': 'Z',
                          'datum_telenja': '2020-05-01',
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
          home: DashboardScreen(
            farmsRepository: FarmsRepository(client: client),
            cattleRepository: CattleRepository(client: client),
            uploadRepository: UploadRepository(client: client),
            onLogout: () async {},
          ),
        ),
      );

      expect(find.text('Pocetni dashboard'), findsOneWidget);
      expect(find.widgetWithText(DropdownButtonFormField<String>, 'Odaberi opciju'), findsOneWidget);
      expect(find.text('Goveda'), findsOneWidget);

      await tester.tap(find.text('Goveda'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Goveda'), findsOneWidget);
      expect(find.text('Mila'), findsOneWidget);
    },
  );

  testWidgets(
    'cattle search filters by last 4 digits for short query and full string for long query',
    (tester) async {
      final storage = const TokenStorage();
      final client = ApiClient(tokenStorage: storage);

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

            if (options.path == '/api/gospodarstva/1/animals/') {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'animals': [
                      {
                        'govedo': {
                          'id': 1,
                          'zivotni_broj': 'HR00001234',
                          'ime': 'Mila',
                          'spol': 'Z',
                          'datum_telenja': '2020-05-01',
                          'potomci': [],
                        },
                      },
                      {
                        'govedo': {
                          'id': 2,
                          'zivotni_broj': 'HR00005678',
                          'ime': 'Branka',
                          'spol': 'Z',
                          'datum_telenja': '2020-05-01',
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
          home: CattleListScreen(
            farmsRepository: FarmsRepository(client: client),
            cattleRepository: CattleRepository(client: client),
            uploadRepository: UploadRepository(client: client),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mila'), findsOneWidget);
      expect(find.text('Branka'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Pretraga po zivotnom broju'),
        '678',
      );
      await tester.pumpAndSettle();

      expect(find.text('Branka'), findsOneWidget);
      expect(find.text('Mila'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Pretraga po zivotnom broju'),
        '00001234',
      );
      await tester.pumpAndSettle();

      expect(find.text('Mila'), findsOneWidget);
      expect(find.text('Branka'), findsNothing);
    },
  );
}
