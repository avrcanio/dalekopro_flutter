import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/features/cattle/zivotni_broj_digits.dart';

void main() {
  const zb = 'HR 1234567890';

  test('prazni upit uvijek match', () {
    expect(matchesZivotniBrojSearchQuery(zb, ''), isTrue);
    expect(matchesZivotniBrojSearchQuery(zb, '   '), isTrue);
  });

  test('upit s HR uspoređuje cijeli string', () {
    expect(matchesZivotniBrojSearchQuery(zb, 'hr 123'), isTrue);
    expect(matchesZivotniBrojSearchQuery(zb, 'HR 999'), isFalse);
  });

  test('vise od 4 znamenke u upitu — podudaranje po znamenkama', () {
    expect(matchesZivotniBrojSearchQuery(zb, '1234567890'), isTrue);
    expect(matchesZivotniBrojSearchQuery(zb, '567890'), isTrue);
    expect(matchesZivotniBrojSearchQuery(zb, '1111'), isFalse);
  });

  test('samo znamenke do 4 — prefiks zadnjih četiriju znamenki', () {
    expect(matchesZivotniBrojSearchQuery(zb, '7890'), isTrue);
    expect(matchesZivotniBrojSearchQuery(zb, '78'), isTrue);
    expect(matchesZivotniBrojSearchQuery(zb, '890'), isFalse);
    expect(matchesZivotniBrojSearchQuery(zb, '1234'), isFalse);
  });
}
