import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/features/cattle/models/cattle.dart';

void main() {
  test('uses potomci when present', () {
    final cattle = Cattle.fromApi({
      'govedo': {
        'id': 1,
        'zivotni_broj': 'HR1',
        'ime': 'Mila',
        'potomci': [
          {'id': 2, 'govedo_id': 2, 'zivotni_broj': 'HR2', 'ime': 'Lina'},
        ],
      },
    });

    expect(cattle.hasPotomciField, isTrue);
    expect(cattle.potomci.length, 1);
    expect(cattle.potomci.first.zivotniBroj, 'HR2');
    expect(cattle.potomci.first.govedoId, 2);
  });

  test('hides potomci section when potomci is null', () {
    final cattle = Cattle.fromApi({
      'govedo': {
        'id': 1,
        'zivotni_broj': 'HR1',
        'ime': 'Mila',
        'potomci': null,
      },
    });

    expect(cattle.hasPotomciField, isFalse);
    expect(cattle.potomci, isEmpty);
  });

  test('fallbacks for optional detail fields', () {
    final cattle = Cattle.fromApi({
      'govedo': {'id': 1, 'zivotni_broj': 'HR1', 'ime': 'Mila'},
    });

    expect(cattle.uzrast, '');
    expect(cattle.majka, '');
    expect(cattle.otac, '');
  });
}
