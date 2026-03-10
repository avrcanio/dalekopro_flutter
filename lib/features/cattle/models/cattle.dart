import '../../../core/config/api_config.dart';

class CattleDescendant {
  const CattleDescendant({
    required this.id,
    required this.govedoId,
    required this.zivotniBroj,
    required this.ime,
    required this.datumTelenja,
    required this.spol,
    required this.uzrast,
  });

  final int id;
  final int govedoId;
  final String zivotniBroj;
  final String ime;
  final String datumTelenja;
  final String spol;
  final String uzrast;

  String get displayName => ime.trim().isEmpty ? zivotniBroj : ime;

  factory CattleDescendant.fromApi(Map<String, dynamic> raw) {
    return CattleDescendant(
      id: (raw['id'] as num?)?.toInt() ?? 0,
      govedoId: (raw['govedo_id'] as num?)?.toInt() ?? 0,
      zivotniBroj: raw['zivotni_broj']?.toString() ?? '',
      ime: raw['ime']?.toString() ?? '',
      datumTelenja: raw['datum_telenja']?.toString() ?? '',
      spol: raw['spol']?.toString() ?? '',
      uzrast: raw['uzrast']?.toString() ?? '',
    );
  }
}

class Cattle {
  const Cattle({
    required this.id,
    required this.zivotniBroj,
    required this.ime,
    required this.spol,
    required this.datumTelenja,
    this.posjed = '',
    required this.uzrast,
    required this.majka,
    required this.otac,
    required this.imageUrl,
    this.thumbnailUrl = '',
    this.imageUrls = const [],
    required this.potomci,
    this.hasPotomciField = false,
  });

  final int id;
  final String zivotniBroj;
  final String ime;
  final String spol;
  final String datumTelenja;
  final String posjed;
  final String uzrast;
  final String majka;
  final String otac;
  final String imageUrl;
  final String thumbnailUrl;
  final List<String> imageUrls;
  final List<CattleDescendant> potomci;
  final bool hasPotomciField;

  String get displayName => ime.trim().isEmpty ? zivotniBroj : ime;

  static String _extractText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) {
      final map = value.cast<String, dynamic>();
      return map['zivotni_broj']?.toString() ??
          map['ime']?.toString() ??
          map['naziv']?.toString() ??
          map['label']?.toString() ??
          '';
    }
    return value.toString();
  }

  static String _normalizeUzrastValue(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    final normalized = value.toLowerCase();
    const aliases = <String, String>{
      'krava': 'Krava',
      'junica': 'Junica',
      'junac': 'Junac',
      'tele musko': 'Tele muško',
      'tele muško': 'Tele muško',
      'tele_musko': 'Tele muško',
      'tele-z': 'Tele žensko',
      'tele zensko': 'Tele žensko',
      'tele žensko': 'Tele žensko',
      'tele_zensko': 'Tele žensko',
      'bik': 'Bik',
    };

    return aliases[normalized] ?? value;
  }

  static String _extractUzrastFromBackend(
    Map<String, dynamic> govedo,
    Map<String, dynamic> apiEntry,
  ) {
    final candidates = <dynamic>[
      govedo['uzrast'],
      govedo['kategorija'],
      govedo['kategorija_uzrasta'],
      govedo['vrsta_kategorije'],
      apiEntry['uzrast'],
      apiEntry['kategorija'],
      apiEntry['kategorija_uzrasta'],
      apiEntry['vrsta_kategorije'],
    ];

    for (final candidate in candidates) {
      final extracted = _extractText(candidate).trim();
      if (extracted.isNotEmpty) {
        return _normalizeUzrastValue(extracted);
      }
    }

    return '';
  }

  static String _extractImageUrlFromValue(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      return _normalizeImageUrl(value);
    }
    if (value is Map) {
      final map = value.cast<String, dynamic>();
      final urlCandidate =
          map['url'] ??
          map['profil_url'] ??
          map['thumbnail_url'] ??
          map['slika_url'] ??
          map['image_url'] ??
          map['imageUrl'] ??
          map['path'] ??
          map['file'];
      if (urlCandidate != null) {
        return _normalizeImageUrl(urlCandidate.toString());
      }
      return '';
    }
    return _normalizeImageUrl(value.toString());
  }

  static String _normalizeImageUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      return value;
    }

    if (value.startsWith('//')) {
      return 'https:$value';
    }

    final base = ApiConfig.baseUrl.replaceFirst(RegExp(r'/$'), '');
    if (value.startsWith('/')) {
      return '$base$value';
    }
    return '$base/$value';
  }

  static String _extractImageUrl(
    Map<String, dynamic> govedo,
    Map<String, dynamic> apiEntry,
  ) {
    final candidates = <dynamic>[
      govedo['slika_profil'],
      govedo['slika_url'],
      govedo['slika'],
      govedo['image_url'],
      govedo['imageUrl'],
      govedo['photo_url'],
      govedo['photo'],
      apiEntry['slika_profil'],
      apiEntry['slika_url'],
      apiEntry['slika'],
      apiEntry['image_url'],
      apiEntry['imageUrl'],
      apiEntry['photo_url'],
      apiEntry['photo'],
    ];

    for (final candidate in candidates) {
      final parsed = _extractImageUrlFromValue(candidate);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    return '';
  }

  static List<String> _extractImageUrls(
    Map<String, dynamic> govedo,
    Map<String, dynamic> apiEntry,
  ) {
    final gallery = <String>[];

    void appendFrom(dynamic value) {
      if (value is! List) return;
      for (final item in value) {
        final parsed = _extractImageUrlFromValue(item);
        if (parsed.isNotEmpty && !gallery.contains(parsed)) {
          gallery.add(parsed);
        }
      }
    }

    appendFrom(govedo['slike']);
    appendFrom(apiEntry['slike']);

    return gallery;
  }

  static String _extractThumbnailUrlFromGallery(
    Map<String, dynamic> govedo,
    Map<String, dynamic> apiEntry,
  ) {
    final gallerySources = <dynamic>[govedo['slike'], apiEntry['slike']];
    for (final source in gallerySources) {
      if (source is! List) continue;
      for (final item in source) {
        if (item is! Map) continue;
        final map = item.cast<String, dynamic>();
        final candidate = _extractImageUrlFromValue(
          map['thumbnail_url'] ?? map['thumb_url'],
        );
        if (candidate.isNotEmpty) {
          return candidate;
        }
      }
    }
    return '';
  }

  static String _extractThumbnailUrl(
    Map<String, dynamic> govedo,
    Map<String, dynamic> apiEntry,
  ) {
    final directCandidates = <dynamic>[
      govedo['thumbnail_url'],
      govedo['thumb_url'],
      govedo['slika_thumbnail'],
      apiEntry['thumbnail_url'],
      apiEntry['thumb_url'],
      apiEntry['slika_thumbnail'],
    ];

    for (final candidate in directCandidates) {
      final parsed = _extractImageUrlFromValue(candidate);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    return _extractThumbnailUrlFromGallery(govedo, apiEntry);
  }

  factory Cattle.fromApi(Map<String, dynamic> apiEntry) {
    final govedo =
        (apiEntry['govedo'] as Map?)?.cast<String, dynamic>() ?? apiEntry;

    final hasPotomciField =
        govedo.containsKey('potomci') && govedo['potomci'] != null;
    final potomciRaw = govedo['potomci'];
    final descendants = <CattleDescendant>[];
    if (potomciRaw is List) {
      for (final item in potomciRaw) {
        if (item is Map) {
          descendants.add(CattleDescendant.fromApi(item.cast<String, dynamic>()));
          continue;
        }

        final extracted = _extractText(item);
        if (extracted.isNotEmpty) {
          descendants.add(
            CattleDescendant(
              id: 0,
              govedoId: 0,
              zivotniBroj: extracted,
              ime: '',
              datumTelenja: '',
              spol: '',
              uzrast: '',
            ),
          );
        }
      }
    }

    final imageUrls = _extractImageUrls(govedo, apiEntry);
    final thumbnailUrl = _extractThumbnailUrl(govedo, apiEntry);
    final extractedImageUrl = _extractImageUrl(govedo, apiEntry);
    final primaryImageUrl = extractedImageUrl.isNotEmpty
        ? extractedImageUrl
        : (imageUrls.isNotEmpty ? imageUrls.first : '');

    return Cattle(
      id: (govedo['id'] as num?)?.toInt() ?? 0,
      zivotniBroj: govedo['zivotni_broj']?.toString() ?? '',
      ime: govedo['ime']?.toString() ?? '',
      spol: govedo['spol']?.toString() ?? '',
      datumTelenja: govedo['datum_telenja']?.toString() ?? '',
      posjed: _extractText(govedo['posjed']),
      uzrast: _extractUzrastFromBackend(govedo, apiEntry),
      majka: _extractText(govedo['majka']),
      otac: _extractText(govedo['otac']),
      imageUrl: primaryImageUrl,
      thumbnailUrl: thumbnailUrl,
      imageUrls: imageUrls,
      potomci: descendants,
      hasPotomciField: hasPotomciField,
    );
  }
}
