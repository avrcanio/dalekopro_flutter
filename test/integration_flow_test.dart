import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/core/network/api_client.dart';
import 'package:dalekopro_farma_flutter/core/storage/token_storage.dart';
import 'package:dalekopro_farma_flutter/features/auth/data/auth_repository.dart';
import 'package:dalekopro_farma_flutter/features/auth/presentation/login_screen.dart';
import 'package:dalekopro_farma_flutter/features/cattle/data/cattle_repository.dart';
import 'package:dalekopro_farma_flutter/features/dashboard/presentation/dashboard_screen.dart';
import 'package:dalekopro_farma_flutter/features/farms/data/farms_repository.dart';
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

  testWidgets('full flow login -> dashboard -> upload screen', (
    tester,
  ) async {
    final tokenStorage = const TokenStorage();
    final client = ApiClient(tokenStorage: tokenStorage);

    client.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/auth/login/' &&
              options.method.toUpperCase() == 'POST') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'token': 'demo-token',
                  'user': {'id': 1, 'username': 'demo_user'},
                },
              ),
            );
            return;
          }

          if (options.path == '/api/gospodarstva/' &&
              options.method.toUpperCase() == 'GET') {
            handler.resolve(
              Response<List<Map<String, dynamic>>>(
                requestOptions: options,
                statusCode: 200,
                data: [
                  {
                    'id': 5,
                    'naziv_gospodarstva': 'OPG Horvat',
                    'naziv_farme': 'Farma 1',
                  },
                ],
              ),
            );
            return;
          }

          if (options.path == '/api/gospodarstva/5/animals/' &&
              options.method.toUpperCase() == 'GET') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'animals': [
                    {
                      'govedo': {
                        'id': 77,
                        'zivotni_broj': 'HR123',
                        'ime': 'Mila',
                        'spol': 'Z',
                        'datum_telenja': '2020-05-01',
                        'potomci': ['HR999'],
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
              response: Response(requestOptions: options, statusCode: 404),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    final authRepository = AuthRepository(
      client: client,
      tokenStorage: tokenStorage,
    );
    final farmsRepository = FarmsRepository(client: client);
    final cattleRepository = CattleRepository(client: client);
    final uploadRepository = UploadRepository(client: client);

    await tester.pumpWidget(
      _FlowTestApp(
        authRepository: authRepository,
        farmsRepository: farmsRepository,
        cattleRepository: cattleRepository,
        uploadRepository: uploadRepository,
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'demo_user');
    await tester.enterText(find.byType(TextFormField).last, 'demo_pass');
    await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
    await tester.pumpAndSettle();

    expect(find.text('Pocetni dashboard'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Upload'));
    await tester.pumpAndSettle();

    expect(find.text('Upload slike goveda'), findsOneWidget);
    expect(find.textContaining('HR123'), findsOneWidget);
  });

  testWidgets('negative flow login invalid credentials shows 401 message', (
    tester,
  ) async {
    final tokenStorage = const TokenStorage();
    final client = ApiClient(tokenStorage: tokenStorage);

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

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          repository: AuthRepository(
            client: client,
            tokenStorage: tokenStorage,
          ),
          onLogin: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'demo_user');
    await tester.enterText(find.byType(TextFormField).last, 'bad_pass');
    await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Neispravno korisnicko ime ili lozinka'),
      findsOneWidget,
    );
  });
}

class _FlowTestApp extends StatefulWidget {
  const _FlowTestApp({
    required this.authRepository,
    required this.farmsRepository,
    required this.cattleRepository,
    required this.uploadRepository,
  });

  final AuthRepository authRepository;
  final FarmsRepository farmsRepository;
  final CattleRepository cattleRepository;
  final UploadRepository uploadRepository;

  @override
  State<_FlowTestApp> createState() => _FlowTestAppState();
}

class _FlowTestAppState extends State<_FlowTestApp> {
  String? _token;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _token == null
          ? LoginScreen(
              repository: widget.authRepository,
              onLogin: (token) => setState(() => _token = token),
            )
          : DashboardScreen(
              farmsRepository: widget.farmsRepository,
              cattleRepository: widget.cattleRepository,
              uploadRepository: widget.uploadRepository,
              onLogout: () async => setState(() => _token = null),
            ),
    );
  }
}
