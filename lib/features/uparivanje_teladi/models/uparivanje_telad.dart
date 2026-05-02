class UparivanjeTelad {
  const UparivanjeTelad({
    required this.id,
    required this.zivotniBroj,
    required this.spol,
    required this.datumTelenja,
    required this.gospodarstvoId,
    required this.posjedVezaId,
    this.majkaNaGospodarstvuId,
    this.otacId,
    this.posjedDisplay = '',
    this.majkaDisplay = '',
    this.otacDisplay = '',
    this.spolDisplay = '',
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String zivotniBroj;
  final String spol;
  final DateTime? datumTelenja;
  final int gospodarstvoId;
  final int posjedVezaId;
  final int? majkaNaGospodarstvuId;
  final int? otacId;
  final String posjedDisplay;
  final String majkaDisplay;
  final String otacDisplay;
  final String spolDisplay;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static int? _int(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.toInt();
    }
    return int.tryParse(v.toString());
  }

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

  static String _str(dynamic v) => v?.toString().trim() ?? '';

  factory UparivanjeTelad.fromJson(Map<String, dynamic> json) {
    return UparivanjeTelad(
      id: _int(json['id']) ?? 0,
      zivotniBroj: _str(json['zivotni_broj']),
      spol: _str(json['spol']),
      datumTelenja: _parseDate(json['datum_telenja']),
      gospodarstvoId: _int(json['gospodarstvo']) ?? 0,
      posjedVezaId: _int(json['posjed_veza']) ?? 0,
      majkaNaGospodarstvuId: _int(json['majka_na_gospodarstvu']),
      otacId: _int(json['otac']),
      posjedDisplay: _str(json['posjed_display']),
      majkaDisplay: _str(json['majka_display']),
      otacDisplay: _str(json['otac_display']),
      spolDisplay: _str(json['spol_display']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  String get spolZaPrikaz =>
      spolDisplay.isNotEmpty ? spolDisplay : (spol == 'M' ? 'Muško' : 'Žensko');
}
