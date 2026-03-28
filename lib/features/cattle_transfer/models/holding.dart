class Holding {
  const Holding({required this.id, required this.name});

  final int id;
  final String name;

  String get label => name.trim();

  static int _extractId(dynamic candidate) {
    if (candidate is num) {
      return candidate.toInt();
    }
    if (candidate is String) {
      return int.tryParse(candidate.trim()) ?? 0;
    }
    if (candidate is Map) {
      final map = candidate.cast<String, dynamic>();
      final nestedCandidates = <dynamic>[
        map['id'],
        map['posjed_veza_id'],
        map['posjed_id'],
        map['value'],
      ];
      for (final nested in nestedCandidates) {
        final resolved = _extractId(nested);
        if (resolved > 0) {
          return resolved;
        }
      }
    }
    return 0;
  }

  static String _extractName(dynamic candidate) {
    if (candidate == null) {
      return '';
    }
    if (candidate is String) {
      return candidate.trim();
    }
    if (candidate is Map) {
      final map = candidate.cast<String, dynamic>();
      final nestedCandidates = <dynamic>[
        map['parcela_posjed_display'],
        map['naziv'],
        map['name'],
        map['label'],
        map['ime'],
        map['posjed'],
        map['display_name'],
        map['title'],
      ];
      for (final nested in nestedCandidates) {
        final resolved = _extractName(nested);
        if (resolved.isNotEmpty) {
          return resolved;
        }
      }
    }
    return candidate.toString().trim();
  }

  factory Holding.fromJson(Map<String, dynamic> json) {
    final idCandidates = <dynamic>[
      json['id'],
      json['posjed_veza_id'],
      json['posjed_id'],
      json['value'],
      json['posjed'],
    ];

    var resolvedId = 0;
    for (final candidate in idCandidates) {
      final value = _extractId(candidate);
      if (value > 0) {
        resolvedId = value;
        break;
      }
    }

    final nameCandidates = <dynamic>[
      json['parcela_posjed_display'],
      json['naziv'],
      json['name'],
      json['label'],
      json['ime'],
      json['posjed'],
      json['display_name'],
      json['title'],
    ];

    var resolvedName = '';
    for (final candidate in nameCandidates) {
      final value = _extractName(candidate);
      if (value.isNotEmpty) {
        resolvedName = value;
        break;
      }
    }

    return Holding(id: resolvedId, name: resolvedName);
  }
}
