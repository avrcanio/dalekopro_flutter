import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/core/platform/share_intent_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('consumePendingSharePath returns null without Android plugin', () async {
    expect(await ShareIntentBridge.consumePendingSharePath(), isNull);
  });
}
