import 'models/cattle.dart';

/// Redoslijed kao u detalju: galerija, zatim profil/thumbnail.
List<String> cattleGalleryImageUrls(Cattle cow) {
  final seen = <String>{};
  final ordered = <String>[];
  void add(String raw) {
    final u = raw.trim();
    if (u.isEmpty || seen.contains(u)) {
      return;
    }
    seen.add(u);
    ordered.add(u);
  }

  for (final u in cow.imageUrls) {
    add(u);
  }
  if (ordered.isEmpty) {
    add(cow.imageUrl);
    add(cow.thumbnailUrl);
  }
  return ordered;
}
