import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/core/network/api_client.dart';
import 'package:dalekopro_farma_flutter/core/storage/token_storage.dart';
import 'package:dalekopro_farma_flutter/features/cattle/data/cattle_repository.dart';
import 'package:dalekopro_farma_flutter/features/cattle/presentation/cattle_list_screen.dart';
import 'package:dalekopro_farma_flutter/features/farms/data/farms_repository.dart';
import 'package:dalekopro_farma_flutter/features/farms/models/farm.dart';
import 'package:dalekopro_farma_flutter/features/upload/data/upload_repository.dart';

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

  ApiClient buildClientWithGroupedCattle() {
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
                  {
                    'id': 2,
                    'naziv_gospodarstva': 'OPG B',
                    'naziv_farme': 'Farma B',
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
                        'zivotni_broj': 'HR0001',
                        'ime': 'BikOne',
                        'uzrast': {'naziv': 'Bik'},
                        'posjed_veza_id': 10,
                        'posjed': {'naziv': 'Kuća'},
                        'potomci': [],
                      },
                    },
                    {
                      'govedo': {
                        'id': 2,
                        'zivotni_broj': 'HR0002',
                        'ime': 'KravaOne',
                        'uzrast': {'naziv': 'Krava'},
                        'posjed_veza_id': 10,
                        'posjed': {'naziv': 'Kuća'},
                        'potomci': [],
                      },
                    },
                    {
                      'govedo': {
                        'id': 3,
                        'zivotni_broj': 'HR0003',
                        'ime': 'JunacOne',
                        'uzrast': {'naziv': 'Junac'},
                        'posjed_veza_id': 11,
                        'posjed': {'naziv': 'Pašnjak'},
                        'potomci': [],
                      },
                    },
                    {
                      'govedo': {
                        'id': 4,
                        'zivotni_broj': 'HR0004',
                        'ime': 'JunicaOne',
                        'uzrast': {'naziv': 'Junica'},
                        'posjed_veza_id': 11,
                        'posjed': {'naziv': 'Pašnjak'},
                        'potomci': [],
                      },
                    },
                    {
                      'govedo': {
                        'id': 5,
                        'zivotni_broj': 'HR0005',
                        'ime': 'TeleM',
                        'uzrast': {'naziv': 'Tele musko'},
                        'posjed_veza_id': 12,
                        'posjed': {'naziv': 'Štala'},
                        'potomci': [],
                      },
                    },
                    {
                      'govedo': {
                        'id': 6,
                        'zivotni_broj': 'HR0006',
                        'ime': 'TeleZ',
                        'uzrast': {'naziv': 'Tele zensko'},
                        'posjed_veza_id': 12,
                        'posjed': {'naziv': 'Štala'},
                        'potomci': [],
                      },
                    },
                    {
                      'govedo': {
                        'id': 7,
                        'zivotni_broj': 'HR0007',
                        'ime': 'UnknownOne',
                        'uzrast': {'naziv': 'Senior'},
                        'posjed_veza_id': 13,
                        'posjed': {'naziv': 'Ispust'},
                        'potomci': [],
                      },
                    },
                  ],
                },
              ),
            );
            return;
          }

          if (options.path == '/api/gospodarstva/2/animals/') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'animals': [
                    {
                      'govedo': {
                        'id': 21,
                        'zivotni_broj': 'HR2001',
                        'ime': 'Farm2Krava',
                        'uzrast': {'naziv': 'Krava'},
                        'posjed_veza_id': 20,
                        'posjed': {'naziv': 'Brdo'},
                        'potomci': [],
                      },
                    },
                    {
                      'govedo': {
                        'id': 22,
                        'zivotni_broj': 'HR2002',
                        'ime': 'Farm2Tele',
                        'uzrast': {'naziv': 'Tele musko'},
                        'posjed_veza_id': 21,
                        'posjed': {'naziv': 'Dolina'},
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

    return client;
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    final client = buildClientWithGroupedCattle();
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
  }

  testWidgets('shows ordered uzrast groups and maps Junac to June', (
    tester,
  ) async {
    await pumpScreen(tester);

    final scrollable = find.byType(Scrollable).first;
    final bik = find.textContaining('Bik (');
    final krava = find.textContaining('Krava (');
    final june = find.textContaining('June (');
    final junica = find.textContaining('Junica (');
    final teleMusko = find.textContaining('Tele muško (');
    final teleZensko = find.textContaining('Tele žensko (');
    final unknown = find.textContaining('Senior (');

    expect(bik, findsOneWidget);
    await tester.scrollUntilVisible(krava, 250, scrollable: scrollable);
    expect(krava, findsOneWidget);
    await tester.scrollUntilVisible(june, 250, scrollable: scrollable);
    expect(june, findsOneWidget);
    await tester.scrollUntilVisible(junica, 250, scrollable: scrollable);
    expect(junica, findsOneWidget);
    await tester.scrollUntilVisible(teleMusko, 250, scrollable: scrollable);
    expect(teleMusko, findsOneWidget);
    await tester.scrollUntilVisible(teleZensko, 250, scrollable: scrollable);
    expect(teleZensko, findsOneWidget);
    await tester.scrollUntilVisible(unknown, 250, scrollable: scrollable);
    expect(unknown, findsOneWidget);
    expect(find.text('Junac (1)'), findsNothing);
  });

  testWidgets('can collapse and expand a uzrast group', (tester) async {
    await pumpScreen(tester);

    expect(find.text('BikOne'), findsOneWidget);

    await tester.tap(find.text('Bik (1)'));
    await tester.pumpAndSettle();
    expect(find.text('BikOne'), findsNothing);

    await tester.tap(find.text('Bik (1)'));
    await tester.pumpAndSettle();
    expect(find.text('BikOne'), findsOneWidget);
  });

  testWidgets(
    'shows all holdings by default and updates counts for one holding',
    (tester) async {
      await pumpScreen(tester);

      expect(find.text('Goveda (7)'), findsOneWidget);
      expect(find.byKey(const Key('holding-filter-summary')), findsOneWidget);
      expect(find.text('Svi posjedi'), findsOneWidget);

      await tester.tap(find.byKey(const Key('holding-filter-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('holding-filter-option-id:10')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Primijeni'));
      await tester.pumpAndSettle();

      expect(find.text('Posjedi (1 odabrano)'), findsOneWidget);
      expect(find.text('Goveda (2)'), findsOneWidget);
      expect(find.text('Bik (1)'), findsOneWidget);
      expect(find.text('Krava (1)'), findsOneWidget);
      expect(find.text('BikOne'), findsOneWidget);
      expect(find.text('KravaOne'), findsOneWidget);
      expect(find.text('JunacOne'), findsNothing);
      expect(find.text('TeleM'), findsNothing);
    },
  );

  testWidgets(
    'supports multiple holdings and combines search with holding filter',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('holding-filter-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('holding-filter-option-id:10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('holding-filter-option-id:11')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Primijeni'));
      await tester.pumpAndSettle();

      expect(find.text('Posjedi (2 odabrano)'), findsOneWidget);
      expect(find.text('Goveda (4)'), findsOneWidget);
      expect(find.text('Bik (1)'), findsOneWidget);
      expect(find.text('Krava (1)'), findsOneWidget);
      expect(find.text('BikOne'), findsOneWidget);
      expect(find.text('KravaOne'), findsOneWidget);
      expect(find.text('JunacOne'), findsOneWidget);
      expect(find.text('TeleM'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Pretraga po zivotnom broju'),
        '0003',
      );
      await tester.pumpAndSettle();

      expect(find.text('Goveda (1)'), findsOneWidget);
      expect(find.text('June (1)'), findsOneWidget);
      expect(find.text('JunacOne'), findsOneWidget);
      expect(find.text('KravaOne'), findsNothing);
    },
  );

  testWidgets('resets holding filter when active farm changes', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('holding-filter-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('holding-filter-option-id:10')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Primijeni'));
    await tester.pumpAndSettle();

    expect(find.text('Goveda (2)'), findsOneWidget);
    expect(find.text('Posjedi (1 odabrano)'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<Farm>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPG B (Farma B)').last);
    await tester.pumpAndSettle();

    expect(find.text('Svi posjedi'), findsOneWidget);
    expect(find.text('Goveda (2)'), findsOneWidget);
    expect(find.text('Farm2Krava'), findsOneWidget);
    expect(find.text('Farm2Tele'), findsOneWidget);
    expect(find.text('BikOne'), findsNothing);
  });
}
