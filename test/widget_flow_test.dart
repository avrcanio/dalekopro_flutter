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
import 'package:dalekopro_farma_flutter/features/nedostatak_markica/data/nedostatak_markica_repository.dart';
import 'package:dalekopro_farma_flutter/features/settings/presentation/settings_screen.dart';
import 'package:dalekopro_farma_flutter/features/upload/data/upload_repository.dart';
import 'package:dalekopro_farma_flutter/features/upload/presentation/upload_screen.dart';
import 'package:dalekopro_farma_flutter/features/uparivanje_teladi/data/uparivanje_teladi_repository.dart';

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
    const SafBridge().clearSessionCache();
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

  testWidgets('password field toggles obscure text', (tester) async {
    final storage = const TokenStorage();
    final client = ApiClient(tokenStorage: storage);
    final repo = AuthRepository(client: client, tokenStorage: storage);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(repository: repo, onLogin: (_) {}),
      ),
    );

    final passwordFieldFinder = find.byType(TextFormField).last;
    final passwordTextField = find.descendant(
      of: passwordFieldFinder,
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(passwordTextField).obscureText, isTrue);

    await tester.tap(find.byTooltip('Prikaži lozinku'));
    await tester.pump();

    expect(tester.widget<TextField>(passwordTextField).obscureText, isFalse);

    await tester.tap(find.byTooltip('Sakrij lozinku'));
    await tester.pump();

    expect(tester.widget<TextField>(passwordTextField).obscureText, isTrue);
  });

  testWidgets('upload screen applies initialSharedCachePath through crop override', (
    tester,
  ) async {
    final storage = const TokenStorage();
    final client = ApiClient(tokenStorage: storage);
    final path = '${Directory.systemTemp.path}/share_intent_upload_test.png';
    File(path).writeAsBytesSync(_tinyPngBytes);
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
          repository: UploadRepository(client: client),
          storage: storage,
          initialSharedCachePath: path,
          initialSelectedCattleForTest: cattle.first,
          cropImageOverride: (f) => Future<File?>.value(f),
          skipExifForTest: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('upload-button')), findsOneWidget);
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
    expect(bridge.listImagesCallCount, 1);

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

  testWidgets('Iz SAF foldera button shows loading state and reuses cache', (
    tester,
  ) async {
    final storage = const TokenStorage();
    await storage.saveFolderUri('content://tree/cached');
    final client = ApiClient(tokenStorage: storage);
    final bridge = _FakeSafBridge(
      images: const <SafImageEntry>[
        SafImageEntry(
          uri: 'content://images/1',
          displayName: 'one.jpg',
          mimeType: 'image/jpeg',
          lastModifiedMillis: 1000,
        ),
      ],
      copiedFilePath: '',
      listDelay: const Duration(milliseconds: 100),
    );
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
          repository: UploadRepository(client: client),
          storage: storage,
          safBridge: bridge,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Iz SAF foldera'));
    await tester.pump();

    expect(find.text('Ucitavanje...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Odabir slike iz SAF foldera'), findsOneWidget);
    expect(bridge.listImagesCallCount, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Iz SAF foldera'));
    await tester.pumpAndSettle();

    expect(find.text('Odabir slike iz SAF foldera'), findsOneWidget);
    expect(bridge.listImagesCallCount, 1);
  });

  testWidgets('SAF crop cancel returns user to picker for another selection', (
    tester,
  ) async {
    final storage = const TokenStorage();
    await storage.saveFolderUri('content://tree/retry');
    final client = ApiClient(tokenStorage: storage);
    final firstFile = File('${Directory.systemTemp.path}/saf_retry_first.jpg');
    firstFile.writeAsBytesSync(_tinyPngBytes);
    final secondFile = File('${Directory.systemTemp.path}/saf_retry_second.jpg');
    secondFile.writeAsBytesSync(_tinyPngBytes);
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
      images: const <SafImageEntry>[
        SafImageEntry(
          uri: 'content://images/first',
          displayName: 'first.jpg',
          mimeType: 'image/jpeg',
          lastModifiedMillis: 2000,
        ),
        SafImageEntry(
          uri: 'content://images/second',
          displayName: 'second.jpg',
          mimeType: 'image/jpeg',
          lastModifiedMillis: 1000,
        ),
      ],
      copiedFilePath: '',
      copiedFilePathsByUri: <String, String>{
        'content://images/first': firstFile.path,
        'content://images/second': secondFile.path,
      },
    );

    var cropCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UploadScreen(
          cattle: cattle,
          repository: UploadRepository(client: client),
          storage: storage,
          safBridge: bridge,
          cropImageOverride: (sourceFile) async {
            cropCalls++;
            if (cropCalls == 1) {
              return null;
            }
            return secondFile;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Iz SAF foldera'));
    await tester.pumpAndSettle();

    expect(find.text('Odabir slike iz SAF foldera'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('saf-image-content://images/first')).hitTestable().first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Odabir slike iz SAF foldera'), findsWidgets);
    expect(find.byKey(const ValueKey('saf-image-content://images/second')), findsWidgets);
    expect(find.text('Crop je otkazan.'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('saf-image-content://images/second')).hitTestable().first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Upload slike goveda'), findsOneWidget);
    expect(cropCalls, 2);
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
    bridge.cacheImagesForTree(
      treeUri: 'content://tree/upload-delete',
      images: const <SafImageEntry>[
        SafImageEntry(
          uri: 'content://images/delete',
          displayName: 'delete.jpg',
          mimeType: 'image/jpeg',
          lastModifiedMillis: 1000,
        ),
      ],
    );
    bridge.cacheThumbnail(
      documentUri: 'content://images/delete',
      bytes: Uint8List.fromList(const <int>[1, 2, 3]),
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
    expect(
      bridge.getCachedImagesForTree(treeUri: 'content://tree/upload-delete'),
      isEmpty,
    );
    expect(
      bridge.getCachedThumbnail(documentUri: 'content://images/delete'),
      isNull,
    );
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

            if (options.path == '/api/gospodarstva/1/posjedi/') {
              handler.resolve(
                Response<List<Map<String, dynamic>>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'id': 10,
                      'parcela_posjed_display': 'Test posjed',
                    },
                  ],
                ),
              );
              return;
            }

            if (options.path ==
                '/api/markiranja/gospodarstva/1/uparivanja-teladi/') {
              handler.resolve(
                Response<List<dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: const <dynamic>[],
                ),
              );
              return;
            }

            if (options.path == '/api/markiranja/nedostatci/') {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'results': <dynamic>[],
                    'next': null,
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
            uparivanjeTeladiRepository: UparivanjeTeladiRepository(client: client),
            nedostatakMarkicaRepository:
                NedostatakMarkicaRepository(client: client),
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
      expect(
        find.widgetWithText(FilledButton, 'Uparivanje teladi'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Nedostatak markica'),
        findsOneWidget,
      );

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

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Uparivanje teladi'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nema zapisa uparivanja'), findsOneWidget);
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
    this.copiedFilePathsByUri = const <String, String>{},
    this.deleteResult = false,
    this.selectedTreeUri,
    this.listDelay = Duration.zero,
  });

  final List<SafImageEntry> images;
  final String copiedFilePath;
  final Map<String, String> copiedFilePathsByUri;
  final bool deleteResult;
  final String? selectedTreeUri;
  final Duration listDelay;
  final List<String> deletedUris = <String>[];
  final List<String?> selectTreeInitialUris = <String?>[];
  int listImagesCallCount = 0;
  int thumbnailLoadCount = 0;

  @override
  Future<String?> selectDocumentTree({String? initialTreeUri}) async {
    selectTreeInitialUris.add(initialTreeUri);
    return selectedTreeUri;
  }

  @override
  Future<List<SafImageEntry>> listImagesFromTree({
    required String treeUri,
  }) async {
    listImagesCallCount++;
    if (listDelay > Duration.zero) {
      await Future<void>.delayed(listDelay);
    }
    cacheImagesForTree(treeUri: treeUri, images: images);
    return images;
  }

  @override
  Future<String?> copyDocumentToCache({
    required String documentUri,
    String? suggestedFileName,
  }) async => copiedFilePathsByUri[documentUri] ?? copiedFilePath;

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
  }) async {
    thumbnailLoadCount++;
    return null;
  }
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
