class Cattle {
  const Cattle({
    required this.id,
    required this.zivotniBroj,
    required this.ime,
    required this.spol,
    required this.datumTelenja,
    required this.potomci,
  });

  final int id;
  final String zivotniBroj;
  final String ime;
  final String spol;
  final String datumTelenja;
  final List<String> potomci;

  factory Cattle.fromApi(Map<String, dynamic> apiEntry) {
    final govedo =
        (apiEntry['govedo'] as Map?)?.cast<String, dynamic>() ?? apiEntry;

    final potomciRaw = govedo['potomci'] ?? govedo['telad'] ?? [];
    final descendants = <String>[];
    if (potomciRaw is List) {
      for (final item in potomciRaw) {
        if (item is String) {
          descendants.add(item);
        } else if (item is Map) {
          final map = item.cast<String, dynamic>();
          descendants.add(
            map['zivotni_broj']?.toString() ??
                map['ime']?.toString() ??
                'Nepoznato potomce',
          );
        }
      }
    }

    return Cattle(
      id: (govedo['id'] as num?)?.toInt() ?? 0,
      zivotniBroj: govedo['zivotni_broj']?.toString() ?? '',
      ime: govedo['ime']?.toString() ?? '',
      spol: govedo['spol']?.toString() ?? '',
      datumTelenja: govedo['datum_telenja']?.toString() ?? '',
      potomci: descendants,
    );
  }
}
