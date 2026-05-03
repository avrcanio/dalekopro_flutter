/// Pretraga životnog broja za odlaske i slične liste:
/// - ako upit sadrži `HR` → podudaranje po cijelom stringu (trim, case-insensitive, substring);
/// - inače ako nakon uklanjanja ne-znamenki ima više od 4 znamenke → podudaranje po znamenkama u životnom broju;
/// - inače ako je upit isključivo znamenke i ≤4 → [matchesZivotniBrojDigitsQuery] (zadnje 4);
/// - inače → substring po cijelom stringu.
bool matchesZivotniBrojSearchQuery(String zivotniBroj, String rawQuery) {
  final q = rawQuery.trim();
  if (q.isEmpty) {
    return true;
  }
  final zb = zivotniBroj.trim();
  final qLower = q.toLowerCase();
  if (qLower.contains('hr')) {
    return zb.toLowerCase().contains(qLower);
  }
  final qDigits = q.replaceAll(RegExp(r'\D'), '');
  if (qDigits.length > 4) {
    final idDigits = zb.replaceAll(RegExp(r'\D'), '');
    return idDigits.contains(qDigits) || zb.toLowerCase().contains(qLower);
  }
  final onlyDigits = RegExp(r'^\d+$').hasMatch(q);
  if (onlyDigits && qDigits.isNotEmpty && qDigits.length <= 4) {
    return matchesZivotniBrojDigitsQuery(zb, qDigits);
  }
  return zb.toLowerCase().contains(qLower);
}

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
