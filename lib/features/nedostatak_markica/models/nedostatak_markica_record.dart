class GovedoMiniRef {
  const GovedoMiniRef({
    required this.id,
    required this.zivotniBroj,
    required this.ime,
  });

  final int id;
  final String zivotniBroj;
  final String ime;

  factory GovedoMiniRef.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const GovedoMiniRef(id: 0, zivotniBroj: '', ime: '');
    }
    return GovedoMiniRef(
      id: (json['id'] as num?)?.toInt() ?? 0,
      zivotniBroj: json['zivotni_broj']?.toString() ?? '',
      ime: json['ime']?.toString() ?? '',
    );
  }
}

class NedostatakMarkicaRecord {
  const NedostatakMarkicaRecord({
    required this.id,
    required this.govedo,
    required this.brojNedostajucih,
    required this.brojNedostajucihDisplay,
    required this.datumPrijave,
    required this.napomena,
    required this.status,
    required this.statusDisplay,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final GovedoMiniRef govedo;
  final int brojNedostajucih;
  final String brojNedostajucihDisplay;
  final DateTime? datumPrijave;
  final String napomena;
  final String status;
  final String statusDisplay;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is DateTime) {
      return v;
    }
    final s = v.toString().trim();
    if (s.isEmpty) {
      return null;
    }
    return DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is DateTime) {
      return v;
    }
    return DateTime.tryParse(v.toString());
  }

  factory NedostatakMarkicaRecord.fromJson(Map<String, dynamic> json) {
    final govedoRaw = json['govedo'];
    return NedostatakMarkicaRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      govedo: GovedoMiniRef.fromJson(
        govedoRaw is Map ? govedoRaw.cast<String, dynamic>() : null,
      ),
      brojNedostajucih: (json['broj_nedostajucih'] as num?)?.toInt() ?? 0,
      brojNedostajucihDisplay:
          json['broj_nedostajucih_display']?.toString() ?? '',
      datumPrijave: _parseDate(json['datum_prijave']),
      napomena: json['napomena']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      statusDisplay: json['status_display']?.toString() ?? '',
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }
}
