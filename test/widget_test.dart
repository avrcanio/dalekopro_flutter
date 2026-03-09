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
          {'zivotni_broj': 'HR2'},
        ],
      },
    });

    expect(cattle.potomci, ['HR2']);
  });

  test('falls back to telad when potomci missing', () {
    final cattle = Cattle.fromApi({
      'govedo': {
        'id': 1,
        'zivotni_broj': 'HR1',
        'ime': 'Mila',
        'telad': [
          {'zivotni_broj': 'HR3'},
        ],
      },
    });

    expect(cattle.potomci, ['HR3']);
  });
}
