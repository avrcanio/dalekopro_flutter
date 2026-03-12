import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/app.dart';
import 'package:dalekopro_farma_flutter/core/storage/token_storage.dart';

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

  testWidgets('without token shows login screen', (tester) async {
    await tester.pumpWidget(const DalekoproApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Prijavi se'), findsOneWidget);
  });

  testWidgets('with token shows dashboard screen', (tester) async {
    const storage = TokenStorage();
    await storage.saveToken('demo-token');

    await tester.pumpWidget(const DalekoproApp());
    await tester.pumpAndSettle();

    expect(find.text('Pocetni dashboard'), findsOneWidget);
    expect(find.text('Goveda'), findsOneWidget);
  });
}
