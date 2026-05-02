class ParentCandidate {
  const ParentCandidate({required this.id, required this.label});

  final int id;
  final String label;

  static ParentCandidate? fromJsonMap(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = idRaw is num
        ? idRaw.toInt()
        : int.tryParse(idRaw?.toString() ?? '');
    if (id == null || id <= 0) {
      return null;
    }
    final label = json['label']?.toString().trim() ?? '';
    if (label.isEmpty) {
      return ParentCandidate(id: id, label: 'ID $id');
    }
    return ParentCandidate(id: id, label: label);
  }
}
