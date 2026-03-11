import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/core/network/api_client.dart';
import 'package:dalekopro_farma_flutter/core/storage/token_storage.dart';
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
}
