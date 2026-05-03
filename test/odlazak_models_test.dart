import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/features/odlasci/models/odlazak_models.dart';

void main() {
  test('OdlazakRecord.fromJson i matchesZivotniBrojQuery', () {
    final r = OdlazakRecord.fromJson(<String, dynamic>{
      'id': 1,
      'serijski_broj': '100000001',
      'datum_odlaska': '2025-01-01',
      'razlog': 5,
      'razlog_label': 'Krađa / Gubitak',
      'goveda': [
        <String, dynamic>{
          'id': 10,
          'zivotni_broj': 'HR 9999999999',
          'ime': 'X',
          'uzrast': 'Krava',
        },
      ],
    });
    expect(r.serijskiBroj, '100000001');
    expect(
      r.matchesZivotniBrojQuery((zb) => zb.contains('9999999999')),
      isTrue,
    );
  });

  test('OdlasciLookupData.fromJson prazni ključevi', () {
    final l = OdlasciLookupData.fromJson(<String, dynamic>{});
    expect(l.klaonice, isEmpty);
  });
}
