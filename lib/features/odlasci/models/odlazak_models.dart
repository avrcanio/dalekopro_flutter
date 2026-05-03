/// Razlozi odlaska (usklađeno s backend `RazlogOdlaska`).
abstract class RazlogOdlaska {
  static const int naDrugoGospodarstvo = 1;
  static const int klaonica = 2;
  static const int kradjaGubitak = 5;
  static const int uginuce = 6;

  static const List<int> all = <int>[
    naDrugoGospodarstvo,
    klaonica,
    kradjaGubitak,
    uginuce,
  ];

  static String labelHr(int razlog) {
    switch (razlog) {
      case naDrugoGospodarstvo:
        return 'Odlazak na drugo gospodarstvo';
      case klaonica:
        return 'Odlazak u klaonicu';
      case kradjaGubitak:
        return 'Krađa / Gubitak';
      case uginuce:
        return 'Uginuće';
      default:
        return 'Razlog $razlog';
    }
  }
}

class GovedoRef {
  const GovedoRef({
    required this.id,
    required this.zivotniBroj,
    required this.ime,
    this.uzrast,
  });

  final int id;
  final String zivotniBroj;
  final String ime;
  final String? uzrast;

  factory GovedoRef.fromJson(Map<String, dynamic> json) {
    return GovedoRef(
      id: (json['id'] as num?)?.toInt() ?? 0,
      zivotniBroj: json['zivotni_broj']?.toString() ?? '',
      ime: json['ime']?.toString() ?? '',
      uzrast: json['uzrast']?.toString(),
    );
  }

  String get subtitle {
    final u = uzrast;
    if (u == null || u.isEmpty) {
      return zivotniBroj;
    }
    return '$zivotniBroj — $u';
  }
}

class OdlazakRecord {
  const OdlazakRecord({
    required this.id,
    required this.serijskiBroj,
    required this.datumOdlaska,
    required this.razlog,
    required this.razlogLabel,
    required this.goveda,
    this.drugoGospodarstvoId,
    this.drugoGospodarstvoLabel,
    this.klaonicaId,
    this.klaonicaLabel,
    this.brojVeterinarskogCertifikata = '',
    this.kafilerijaId,
    this.kafilerijaLabel,
    this.datumPrijaveVeterinaru,
    this.veterinarId,
    this.veterinarLabel,
    this.voziloId,
    this.voziloLabel,
    this.napomenaPrijevoz = '',
    this.napomena = '',
  });

  final int id;
  final String serijskiBroj;
  final String datumOdlaska;
  final int razlog;
  final String razlogLabel;
  final List<GovedoRef> goveda;
  final int? drugoGospodarstvoId;
  final String? drugoGospodarstvoLabel;
  final int? klaonicaId;
  final String? klaonicaLabel;
  final String brojVeterinarskogCertifikata;
  final int? kafilerijaId;
  final String? kafilerijaLabel;
  final String? datumPrijaveVeterinaru;
  final int? veterinarId;
  final String? veterinarLabel;
  final int? voziloId;
  final String? voziloLabel;
  final String napomenaPrijevoz;
  final String napomena;

  factory OdlazakRecord.fromJson(Map<String, dynamic> json) {
    final govedaRaw = json['goveda'];
    final goveda = govedaRaw is List
        ? govedaRaw
              .whereType<Map>()
              .map((e) => GovedoRef.fromJson(e.cast<String, dynamic>()))
              .toList()
        : const <GovedoRef>[];

    return OdlazakRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      serijskiBroj: json['serijski_broj']?.toString() ?? '',
      datumOdlaska: json['datum_odlaska']?.toString() ?? '',
      razlog: (json['razlog'] as num?)?.toInt() ?? 0,
      razlogLabel: json['razlog_label']?.toString() ?? '',
      goveda: goveda,
      drugoGospodarstvoId: (json['drugo_gospodarstvo'] as num?)?.toInt(),
      drugoGospodarstvoLabel: json['drugo_gospodarstvo_label']?.toString(),
      klaonicaId: (json['klaonica'] as num?)?.toInt(),
      klaonicaLabel: json['klaonica_label']?.toString(),
      brojVeterinarskogCertifikata:
          json['broj_veterinarskog_certifikata']?.toString() ?? '',
      kafilerijaId: (json['kafilerija'] as num?)?.toInt(),
      kafilerijaLabel: json['kafilerija_label']?.toString(),
      datumPrijaveVeterinaru: json['datum_prijave_veterinaru']?.toString(),
      veterinarId: (json['veterinar'] as num?)?.toInt(),
      veterinarLabel: json['veterinar_label']?.toString(),
      voziloId: (json['vozilo'] as num?)?.toInt(),
      voziloLabel: json['vozilo_label']?.toString(),
      napomenaPrijevoz: json['napomena_prijevoz']?.toString() ?? '',
      napomena: json['napomena']?.toString() ?? '',
    );
  }

  bool matchesZivotniBrojQuery(bool Function(String zivotniBroj) matcher) {
    for (final g in goveda) {
      if (matcher(g.zivotniBroj)) {
        return true;
      }
    }
    return false;
  }

  String govedaSummary() {
    if (goveda.isEmpty) {
      return '—';
    }
    final first = goveda.first;
    final zb = first.zivotniBroj;
    if (goveda.length == 1) {
      return zb;
    }
    return '$zb +${goveda.length - 1}';
  }
}

class LookupItem {
  const LookupItem({
    required this.id,
    required this.label,
  });

  final int id;
  final String label;

  factory LookupItem.fromJson(Map<String, dynamic> json) {
    return LookupItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString() ?? '',
    );
  }
}

class OdlasciLookupData {
  const OdlasciLookupData({
    this.drugaGospodarstva = const [],
    this.klaonice = const [],
    this.kafilerije = const [],
    this.veterinari = const [],
    this.vozila = const [],
  });

  final List<LookupItem> drugaGospodarstva;
  final List<LookupItem> klaonice;
  final List<LookupItem> kafilerije;
  final List<LookupItem> veterinari;
  final List<LookupItem> vozila;

  factory OdlasciLookupData.fromJson(Map<String, dynamic> json) {
    List<LookupItem> parseList(String key) {
      final raw = json[key];
      if (raw is! List) {
        return const [];
      }
      return raw
          .whereType<Map>()
          .map((e) => LookupItem.fromJson(e.cast<String, dynamic>()))
          .where((e) => e.id > 0 && e.label.isNotEmpty)
          .toList();
    }

    return OdlasciLookupData(
      drugaGospodarstva: parseList('druga_gospodarstva'),
      klaonice: parseList('klaonice'),
      kafilerije: parseList('kafilerije'),
      veterinari: parseList('veterinari'),
      vozila: parseList('vozila'),
    );
  }
}
