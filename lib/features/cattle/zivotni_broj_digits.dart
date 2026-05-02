/// Pretraga životnog broja po znamenkama (npr. zadnje 4).
bool matchesZivotniBrojDigitsQuery(String zivotniBroj, String queryDigits) {
  if (queryDigits.isEmpty) {
    return true;
  }
  final idDigits = zivotniBroj.replaceAll(RegExp(r'\D'), '');
  if (idDigits.isEmpty) {
    return false;
  }
  final last4 = idDigits.length >= 4
      ? idDigits.substring(idDigits.length - 4)
      : idDigits;
  if (queryDigits.length <= 4) {
    return last4.startsWith(queryDigits);
  }
  return idDigits.endsWith(queryDigits);
}

/// Indeks prvog znaka u [zbroj] koji pripada bloku zadnjih [count] znamenki.
int startIndexOfLastDigits(String zbroj, int count) {
  final digitIndices = <int>[];
  for (var i = 0; i < zbroj.length; i++) {
    final c = zbroj.codeUnitAt(i);
    if (c >= 0x30 && c <= 0x39) {
      digitIndices.add(i);
    }
  }
  if (digitIndices.isEmpty) {
    return zbroj.length;
  }
  final take = count < digitIndices.length ? count : digitIndices.length;
  return digitIndices[digitIndices.length - take];
}
