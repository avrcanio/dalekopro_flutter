class Farm {
  const Farm({
    required this.id,
    required this.nazivGospodarstva,
    required this.nazivFarme,
  });

  final int id;
  final String nazivGospodarstva;
  final String nazivFarme;

  String get label {
    if (nazivFarme.isEmpty) {
      return nazivGospodarstva;
    }
    return '$nazivGospodarstva ($nazivFarme)';
  }

  factory Farm.fromJson(Map<String, dynamic> json) {
    return Farm(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nazivGospodarstva: json['naziv_gospodarstva']?.toString() ?? '',
      nazivFarme: json['naziv_farme']?.toString() ?? '',
    );
  }
}
