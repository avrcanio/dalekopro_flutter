import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:dalekopro_farma_flutter/core/network/api_client.dart';
import 'package:dalekopro_farma_flutter/core/storage/token_storage.dart';
import 'package:dalekopro_farma_flutter/features/cattle/data/cattle_repository.dart';
import 'package:dalekopro_farma_flutter/features/cattle/models/cattle.dart';
import 'package:dalekopro_farma_flutter/features/cattle/presentation/cattle_list_screen.dart';
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

  UploadRepository buildUploadRepository() {
    final client = ApiClient(tokenStorage: const TokenStorage());
    return UploadRepository(client: client);
  }

  CattleRepository buildCattleRepository() {
    final client = ApiClient(tokenStorage: const TokenStorage());
    return CattleRepository(client: client);
  }

  Cattle buildCattle({
    required List<String> imageUrls,
    String imageUrl = '',
    List<CattleDescendant> potomci = const [],
  }) {
    return Cattle(
      id: 1,
      zivotniBroj: 'HR4201833285',
      ime: 'VITA',
      spol: 'Z',
      datumTelenja: '23.01.2025',
      posjed: 'Cista',
      uzrast: 'Junica',
      majka: 'HR9200967481',
      otac: 'JABLAN LB4',
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      potomci: potomci,
      hasPotomciField: true,
    );
  }

  double thumbBorderWidth(WidgetTester tester, int index) {
    final container = tester.widget<AnimatedContainer>(
      find.byKey(Key('cattle-detail-thumb-$index')),
    );
    final decoration = container.decoration! as BoxDecoration;
    return (decoration.border! as Border).top.width;
  }

  testWidgets('hides potomci section when descendant list is empty', (
    tester,
  ) async {
    final cattle = buildCattle(
      imageUrl: 'https://example.com/main.jpg',
      imageUrls: const ['https://example.com/1.jpg'],
      potomci: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CattleDetailScreen(
          cattle: cattle,
          allCattle: const [],
          cattleRepository: buildCattleRepository(),
          uploadRepository: buildUploadRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Potomci:'), findsNothing);
    expect(find.text('Nema dostupnih potomaka'), findsNothing);
  });

  testWidgets('shows posjed before zivotni broj', (tester) async {
    final cattle = buildCattle(
      imageUrl: 'https://example.com/main.jpg',
      imageUrls: const ['https://example.com/1.jpg'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CattleDetailScreen(
          cattle: cattle,
          allCattle: const [],
          cattleRepository: buildCattleRepository(),
          uploadRepository: buildUploadRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final posjedFinder = find.textContaining('Posjed:', skipOffstage: false);
    final brojFinder = find.textContaining(
      'Zivotni broj:',
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(
      brojFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(posjedFinder, findsOneWidget);
    expect(brojFinder, findsOneWidget);
    expect(
      tester.getTopLeft(posjedFinder).dy,
      lessThan(tester.getTopLeft(brojFinder).dy),
    );
  });

  testWidgets('carousel supports swipe, thumbnail tap and autoplay loop', (
    tester,
  ) async {
    final cattle = buildCattle(
      imageUrl: 'https://example.com/main.jpg',
      imageUrls: const [
        'https://example.com/1.jpg',
        'https://example.com/2.jpg',
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CattleDetailScreen(
          cattle: cattle,
          allCattle: const [],
          cattleRepository: buildCattleRepository(),
          uploadRepository: buildUploadRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('cattle-detail-pageview')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('cattle-detail-thumb-2')),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(thumbBorderWidth(tester, 0), 2);
    expect(thumbBorderWidth(tester, 1), 1);
    expect(thumbBorderWidth(tester, 2), 1);

    await tester.fling(
      find.byKey(const Key('cattle-detail-pageview')),
      const Offset(-600, 0),
      1200,
    );
    await tester.pumpAndSettle();
    expect(thumbBorderWidth(tester, 0), 1);

    await tester.tap(find.byKey(const Key('cattle-detail-thumb-2')));
    await tester.pumpAndSettle();
    expect(thumbBorderWidth(tester, 2), 2);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(thumbBorderWidth(tester, 0), 2);
  });

  testWidgets('renders majka and otac in structured format', (tester) async {
    final cattle = buildCattle(
      imageUrl: 'https://example.com/main.jpg',
      imageUrls: const ['https://example.com/1.jpg'],
    );
    final cattleWithParents = Cattle(
      id: cattle.id,
      zivotniBroj: cattle.zivotniBroj,
      ime: cattle.ime,
      spol: cattle.spol,
      datumTelenja: cattle.datumTelenja,
      posjed: cattle.posjed,
      uzrast: cattle.uzrast,
      majka: cattle.majka,
      otac: cattle.otac,
      majkaRef: const CattleParentRef(
        id: 114,
        broj: 'HR 1201164650',
        ime: 'BELA B126',
      ),
      otacRef: const CattleParentRef(
        id: 1,
        broj: '87000000158',
        ime: 'JABLAN LB4',
      ),
      imageUrl: cattle.imageUrl,
      imageUrls: cattle.imageUrls,
      potomci: cattle.potomci,
      hasPotomciField: cattle.hasPotomciField,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CattleDetailScreen(
          cattle: cattleWithParents,
          allCattle: const [],
          cattleRepository: buildCattleRepository(),
          uploadRepository: buildUploadRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final majkaFinder = find.textContaining(
      'Majka: HR 1201164650 (BELA B126)',
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(
      majkaFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(majkaFinder, findsOneWidget);
    expect(
      find.textContaining('Otac: 87000000158 (JABLAN LB4)', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('tap on local majka opens parent detail', (tester) async {
    final child = buildCattle(
      imageUrl: 'https://example.com/main.jpg',
      imageUrls: const ['https://example.com/1.jpg'],
    );
    final childWithRef = Cattle(
      id: child.id,
      zivotniBroj: child.zivotniBroj,
      ime: child.ime,
      spol: child.spol,
      datumTelenja: child.datumTelenja,
      posjed: child.posjed,
      uzrast: child.uzrast,
      majka: child.majka,
      otac: child.otac,
      majkaRef: const CattleParentRef(
        id: 2,
        broj: 'HR9200967481',
        ime: 'MAMA',
      ),
      imageUrl: child.imageUrl,
      imageUrls: child.imageUrls,
      potomci: child.potomci,
      hasPotomciField: child.hasPotomciField,
    );
    final parent = Cattle(
      id: 2,
      zivotniBroj: 'HR9200967481',
      ime: 'MAMA',
      spol: 'Z',
      datumTelenja: '01.01.2020',
      posjed: 'Cista',
      uzrast: 'Krava',
      majka: '',
      otac: '',
      imageUrl: '',
      potomci: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CattleDetailScreen(
          cattle: childWithRef,
          allCattle: [childWithRef, parent],
          cattleRepository: buildCattleRepository(),
          uploadRepository: buildUploadRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('cattle-detail-parent-majka')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('cattle-detail-parent-majka')));
    await tester.pumpAndSettle();

    expect(find.text('MAMA'), findsWidgets);
    expect(find.text('Govedo nije na aktivnom gospodarstvu.'), findsNothing);
  });

  testWidgets('fallback API parent fetch shows outside farm notice', (
    tester,
  ) async {
    final storage = const TokenStorage();
    final client = ApiClient(tokenStorage: storage);
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
                  'spol': 'Z',
                  'datum_telenja': '05.02.2019',
                  'uzrast': {'naziv': 'Krava'},
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

    final child = buildCattle(
      imageUrl: 'https://example.com/main.jpg',
      imageUrls: const ['https://example.com/1.jpg'],
    );
    final childWithRef = Cattle(
      id: child.id,
      zivotniBroj: child.zivotniBroj,
      ime: child.ime,
      spol: child.spol,
      datumTelenja: child.datumTelenja,
      posjed: child.posjed,
      uzrast: child.uzrast,
      majka: child.majka,
      otac: child.otac,
      majkaRef: const CattleParentRef(
        id: 114,
        broj: 'HR 1201164650',
        ime: 'BELA B126',
      ),
      imageUrl: child.imageUrl,
      imageUrls: child.imageUrls,
      potomci: child.potomci,
      hasPotomciField: child.hasPotomciField,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CattleDetailScreen(
          cattle: childWithRef,
          allCattle: [childWithRef],
          cattleRepository: CattleRepository(client: client),
          uploadRepository: buildUploadRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('cattle-detail-parent-majka')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('cattle-detail-parent-majka')));
    await tester.pumpAndSettle();

    final noticeFinder = find.text(
      'Govedo nije na aktivnom gospodarstvu.',
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(
      noticeFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(noticeFinder, findsOneWidget);
    expect(find.text('BELA B126', skipOffstage: false), findsWidgets);
  });
}
