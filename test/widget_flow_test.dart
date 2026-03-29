import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/core/network/api_client.dart';
import 'package:dalekopro_farma_flutter/core/storage/saf_bridge.dart';
import 'package:dalekopro_farma_flutter/core/storage/token_storage.dart';
import 'package:dalekopro_farma_flutter/features/auth/data/auth_repository.dart';
import 'package:dalekopro_farma_flutter/features/auth/presentation/login_screen.dart';
import 'package:dalekopro_farma_flutter/features/cattle/data/cattle_repository.dart';
import 'package:dalekopro_farma_flutter/features/cattle/models/cattle.dart';
import 'package:dalekopro_farma_flutter/features/cattle/presentation/cattle_list_screen.dart';
import 'package:dalekopro_farma_flutter/features/cattle_transfer/data/cattle_transfer_repository.dart';
import 'package:dalekopro_farma_flutter/features/dashboard/presentation/dashboard_screen.dart';
import 'package:dalekopro_farma_flutter/features/farms/data/farms_repository.dart';
import 'package:dalekopro_farma_flutter/features/settings/presentation/settings_screen.dart';
import 'package:dalekopro_farma_flutter/features/upload/data/upload_repository.dart';
import 'package:dalekopro_farma_flutter/features/upload/presentation/upload_screen.dart';

import 'test_helpers.dart';

const List<int> _tinyPngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
  0xB1, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
  0x44, 0xAE, 0x42, 0x60, 0x82,
];

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

  testWidgets('cattle list renders avatar images through cache widget', (
    tester,
  ) async {
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
                        'slika_url': 'https://example.com/image-1.jpg',
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
    expect(find.byType(CachedNetworkImage), findsWidgets);
  });

  testWidgets('upload screen starts empty and requires cattle selection', (
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

    expect(find.text('Odaberi govedo iz rezultata pretrage.'), findsOneWidget);
    expect(find.text('HR123 - Mila'), findsNothing);
    expect(find.widgetWithText(TextFormField, ''), findsOneWidget);
    expect(find.text('SAF folder URI'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Odaberi'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Iz SAF foldera'), findsOneWidget);
    expect(find.byKey(const ValueKey('upload-button')), findsNothing);
    expect(find.text('Upload'), findsNothing);

    final searchField = find.byType(TextFormField).first;
    final editableField = find.byType(EditableText).first;

    await tester.tap(searchField);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(tester.widget<EditableText>(editableField).focusNode.hasFocus, isTrue);

    await tester.enterText(searchField, 'HR123');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(ListTile, 'HR123'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Odaberi govedo iz rezultata pretrage.'), findsNothing);
    expect(find.text('HR123 - Mila'), findsOneWidget);
    expect(tester.widget<EditableText>(editableField).focusNode.hasFocus, isFalse);
    expect(find.byKey(const ValueKey('upload-button')), findsNothing);

    await tester.tap(searchField);
    await tester.pump();
    expect(tester.widget<EditableText>(editableField).focusNode.hasFocus, isTrue);
  });

  testWidgets('upload button appears only when image exists and shows progress text', (
    tester,
  ) async {
    final storage = const TokenStorage();
    final client = ApiClient(tokenStorage: storage);
    final sourceFile = File('${Directory.systemTemp.path}/upload_progress_test.jpg');
    sourceFile.writeAsBytesSync(_tinyPngBytes);
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
    final uploadRepo = _FakeUploadRepository(
      client: client,
      result: const UploadResult(status: 'OK', slikaId: 102),
      progressEvents: const <List<int>>[
        <int>[5, 0],
        <int>[50, 100],
        <int>[100, 100],
      ],
      progressDelay: const Duration(milliseconds: 100),
      resultDelay: const Duration(milliseconds: 100),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UploadScreen(
          cattle: cattle,
          repository: uploadRepo,
          storage: storage,
          initialImageForTest: sourceFile,
          initialSelectedCattleForTest: cattle.first,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('upload-button')), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('upload-button')));
    await tester.pump();

    expect(find.text('Saljem...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.textContaining('Upload '), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('upload-button')), findsNothing);
  });

  testWidgets('settings screen saves SAF folder and upload hides SAF config when set', (
    tester,
  ) async {
    final storage = const TokenStorage();
    final bridge = _FakeSafBridge(
      images: const <SafImageEntry>[],
      copiedFilePath: '',
      selectedTreeUri: 'content://com.android.externalstorage.documents/tree/primary%3ADCIM%2FCamera',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          storage: storage,
          safBridge: bridge,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('SAF folder'), findsOneWidget);
    expect(find.text('Nije odabran SAF folder.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Odaberi SAF folder'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Odaberi SAF folder'));
    await tester.pumpAndSettle();

    expect(find.textContaining('SAF folder je uspjesno spremljen'), findsOneWidget);
    expect(
      find.text('content://com.android.externalstorage.documents/tree/primary%3ADCIM%2FCamera'),
      findsOneWidget,
    );
    expect(bridge.selectTreeInitialUris, <String?>[null]);

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
          safBridge: bridge,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SAF folder URI'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Odaberi'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Iz SAF foldera'), findsOneWidget);
  });

  testWidgets('SAF upload offers delete dialog and keeps original on user choice', (
    tester,
  ) async {
    final storage = const TokenStorage();
    final client = ApiClient(tokenStorage: storage);
    final uploadRepo = _FakeUploadRepository(
      client: client,
      result: const UploadResult(status: 'OK', slikaId: 99),
    );
    final sourceFile = File('${Directory.systemTemp.path}/upload_keep_test.jpg');
    sourceFile.writeAsBytesSync(_tinyPngBytes);

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

    final bridge = _FakeSafBridge(
      images: const <SafImageEntry>[],
      copiedFilePath: sourceFile.path,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UploadScreen(
          cattle: cattle,
          repository: uploadRepo,
          storage: storage,
          safBridge: bridge,
          initialImageForTest: sourceFile,
          initialSelectedImageSourceDocumentUri: 'content://images/keep',
          initialSelectedImageSourceName: 'keep.jpg',
          initialSelectedCattleForTest: cattle.first,
        ),
      ),
    );
    final uploadButton = find.byKey(const ValueKey('upload-button'));
    await tester.scrollUntilVisible(
      uploadButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(uploadButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Obrisati originalnu sliku?'), findsOneWidget);
    expect(find.textContaining('keep.jpg'), findsOneWidget);

    await tester.tap(find.text('Zadrzi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Originalna slika je zadrzana'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, ''), findsOneWidget);
    expect(find.text('Odaberi govedo iz rezultata pretrage.'), findsOneWidget);
    expect(bridge.deletedUris, isEmpty);
  });

  testWidgets('SAF upload deletes original when user confirms', (tester) async {
    final storage = const TokenStorage();
    final client = ApiClient(tokenStorage: storage);
    final uploadRepo = _FakeUploadRepository(
      client: client,
      result: const UploadResult(status: 'OK', slikaId: 100),
    );
    final sourceFile = File('${Directory.systemTemp.path}/upload_delete_test.jpg');
    sourceFile.writeAsBytesSync(_tinyPngBytes);

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

    final bridge = _FakeSafBridge(
      images: const <SafImageEntry>[],
      copiedFilePath: sourceFile.path,
      deleteResult: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UploadScreen(
          cattle: cattle,
          repository: uploadRepo,
          storage: storage,
          safBridge: bridge,
          initialImageForTest: sourceFile,
          initialSelectedImageSourceDocumentUri: 'content://images/delete',
          initialSelectedImageSourceName: 'delete.jpg',
          initialSelectedCattleForTest: cattle.first,
        ),
      ),
    );
    final uploadButton = find.byKey(const ValueKey('upload-button'));
    await tester.scrollUntilVisible(
      uploadButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(uploadButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Obrisi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('Originalna slika je obrisana'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, ''), findsOneWidget);
    expect(find.text('Odaberi govedo iz rezultata pretrage.'), findsOneWidget);
    expect(bridge.deletedUris, contains('content://images/delete'));
  });

  testWidgets('camera upload does not offer delete dialog', (tester) async {
    final storage = const TokenStorage();
    final client = ApiClient(tokenStorage: storage);
    final uploadRepo = _FakeUploadRepository(
      client: client,
      result: const UploadResult(status: 'OK', slikaId: 101),
    );
    final sourceFile = File('${Directory.systemTemp.path}/upload_camera_test.jpg');
    sourceFile.writeAsBytesSync(_tinyPngBytes);

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
          initialImageForTest: sourceFile,
          initialSelectedCattleForTest: cattle.first,
        ),
      ),
    );
    final uploadButton = find.byKey(const ValueKey('upload-button'));
    await tester.scrollUntilVisible(
      uploadButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(uploadButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Obrisati originalnu sliku?'), findsNothing);
    expect(find.textContaining('Upload uspjesan: status=OK, slika_id=101'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, ''), findsOneWidget);
    expect(find.text('Odaberi govedo iz rezultata pretrage.'), findsOneWidget);
  });

  testWidgets(
    'dashboard renders dropdown and navigates to cattle list and upload',
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
            cattleTransferRepository: CattleTransferRepository(client: client),
            uploadRepository: UploadRepository(client: client),
            onLogout: () async {},
          ),
        ),
      );

      expect(find.text('Pocetni dashboard'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(
        find.widgetWithText(DropdownButtonFormField<String>, 'Odaberi opciju'),
        findsOneWidget,
      );
      expect(find.text('Goveda'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Upload'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Premjestanje'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('SAF folder'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Goveda'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Goveda'), findsOneWidget);
      expect(find.text('Mila'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload').last);
      await tester.pumpAndSettle();

      expect(find.text('Upload slike goveda'), findsOneWidget);
      expect(find.text('Odaberi govedo iz rezultata pretrage.'), findsOneWidget);
      expect(find.textContaining('HR00001234'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Premjestanje'));
      await tester.pumpAndSettle();

      expect(find.text('Premještanje goveda'), findsOneWidget);
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

class _FakeSafBridge extends SafBridge {
  _FakeSafBridge({
    required this.images,
    required this.copiedFilePath,
    this.deleteResult = false,
    this.selectedTreeUri,
  });

  final List<SafImageEntry> images;
  final String copiedFilePath;
  final bool deleteResult;
  final String? selectedTreeUri;
  final List<String> deletedUris = <String>[];
  final List<String?> selectTreeInitialUris = <String?>[];

  @override
  Future<String?> selectDocumentTree({String? initialTreeUri}) async {
    selectTreeInitialUris.add(initialTreeUri);
    return selectedTreeUri;
  }

  @override
  Future<List<SafImageEntry>> listImagesFromTree({
    required String treeUri,
  }) async => images;

  @override
  Future<String?> copyDocumentToCache({
    required String documentUri,
    String? suggestedFileName,
  }) async => copiedFilePath;

  @override
  Future<bool> deleteDocument({required String documentUri}) async {
    deletedUris.add(documentUri);
    return deleteResult;
  }

  @override
  Future<Uint8List?> loadDocumentThumbnail({
    required String documentUri,
    int width = 512,
    int height = 512,
  }) async => null;
}

class _FakeUploadRepository extends UploadRepository {
  _FakeUploadRepository({
    required ApiClient client,
    required this.result,
    this.progressEvents = const <List<int>>[],
    this.progressDelay = Duration.zero,
    this.resultDelay = Duration.zero,
  }) : super(client: client);

  final UploadResult result;
  final List<List<int>> progressEvents;
  final Duration progressDelay;
  final Duration resultDelay;

  @override
  Future<UploadResult> uploadCattlePhoto({
    required String zivotniBroj,
    required File image,
    String? datum,
    double? latitude,
    double? longitude,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    for (final event in progressEvents) {
      if (progressDelay > Duration.zero) {
        await Future<void>.delayed(progressDelay);
      }
      onSendProgress?.call(event[0], event[1]);
    }
    if (resultDelay > Duration.zero) {
      await Future<void>.delayed(resultDelay);
    }
    return result;
  }
}
