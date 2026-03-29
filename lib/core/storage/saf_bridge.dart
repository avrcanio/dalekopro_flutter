import 'package:flutter/services.dart';

class SafImageEntry {
  const SafImageEntry({
    required this.uri,
    required this.displayName,
    required this.mimeType,
    this.lastModifiedMillis,
    this.sizeBytes,
  });

  final String uri;
  final String displayName;
  final String mimeType;
  final int? lastModifiedMillis;
  final int? sizeBytes;

  factory SafImageEntry.fromMap(Map<dynamic, dynamic> map) {
    return SafImageEntry(
      uri: map['uri']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      mimeType: map['mimeType']?.toString() ?? '',
      lastModifiedMillis: _toInt(map['lastModifiedMillis']),
      sizeBytes: _toInt(map['sizeBytes']),
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class SafBridge {
  const SafBridge();

  static const MethodChannel _channel = MethodChannel('dalekopro/saf');
  static final Map<String, List<SafImageEntry>> _imageListCache =
      <String, List<SafImageEntry>>{};
  static final Map<String, Uint8List> _thumbnailCache = <String, Uint8List>{};
  static final Map<String, Set<String>> _treeDocumentUris =
      <String, Set<String>>{};

  Future<String?> selectDocumentTree({String? initialTreeUri}) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'selectDocumentTree',
      <String, dynamic>{'initialTreeUri': initialTreeUri},
    );
    return response?['treeUri']?.toString();
  }

  Future<String?> pickImageFromTree({required String treeUri}) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'pickImageFromTree',
      <String, dynamic>{'treeUri': treeUri},
    );
    return response?['filePath']?.toString();
  }

  Future<List<SafImageEntry>> listImagesFromTree({
    required String treeUri,
  }) async {
    final response = await _channel.invokeListMethod<dynamic>(
      'listImagesFromTree',
      <String, dynamic>{'treeUri': treeUri},
    );

    final images = (response ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(SafImageEntry.fromMap)
        .where((item) => item.uri.isNotEmpty)
        .toList(growable: false);
    cacheImagesForTree(treeUri: treeUri, images: images);
    return images;
  }

  List<SafImageEntry>? getCachedImagesForTree({required String treeUri}) {
    final cached = _imageListCache[treeUri];
    return cached == null ? null : List<SafImageEntry>.unmodifiable(cached);
  }

  void cacheImagesForTree({
    required String treeUri,
    required List<SafImageEntry> images,
  }) {
    _imageListCache[treeUri] = List<SafImageEntry>.unmodifiable(images);
    _treeDocumentUris[treeUri] = images.map((item) => item.uri).toSet();
  }

  Uint8List? getCachedThumbnail({required String documentUri}) {
    return _thumbnailCache[documentUri];
  }

  void cacheThumbnail({
    required String documentUri,
    required Uint8List bytes,
  }) {
    _thumbnailCache[documentUri] = bytes;
  }

  void clearTreeCache({required String treeUri}) {
    final uris = _treeDocumentUris.remove(treeUri);
    if (uris != null) {
      for (final uri in uris) {
        _thumbnailCache.remove(uri);
      }
    }
    _imageListCache.remove(treeUri);
  }

  void clearSessionCache() {
    _imageListCache.clear();
    _thumbnailCache.clear();
    _treeDocumentUris.clear();
  }

  void removeDocumentFromCache({required String documentUri}) {
    _thumbnailCache.remove(documentUri);
    final treesToUpdate = <String>[];

    for (final entry in _treeDocumentUris.entries) {
      if (entry.value.contains(documentUri)) {
        entry.value.remove(documentUri);
        treesToUpdate.add(entry.key);
      }
    }

    for (final treeUri in treesToUpdate) {
      final cachedImages = _imageListCache[treeUri];
      if (cachedImages == null) {
        continue;
      }
      _imageListCache[treeUri] = List<SafImageEntry>.unmodifiable(
        cachedImages.where((item) => item.uri != documentUri),
      );
    }
  }

  Future<void> prefetchTreeContents({
    required String treeUri,
    int thumbnailLimit = 24,
  }) async {
    final images = await listImagesFromTree(treeUri: treeUri);
    final count = thumbnailLimit < images.length ? thumbnailLimit : images.length;
    for (var index = 0; index < count; index++) {
      final item = images[index];
      try {
        await loadDocumentThumbnail(documentUri: item.uri);
      } catch (_) {
        // Ignore background prefetch failures; picker can still lazy-load.
      }
    }
  }

  Future<String?> copyDocumentToCache({
    required String documentUri,
    String? suggestedFileName,
  }) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'copyDocumentToCache',
      <String, dynamic>{
        'documentUri': documentUri,
        'suggestedFileName': suggestedFileName,
      },
    );
    return response?['filePath']?.toString();
  }

  Future<Uint8List?> loadDocumentThumbnail({
    required String documentUri,
    int width = 512,
    int height = 512,
  }) async {
    final cached = _thumbnailCache[documentUri];
    if (cached != null) {
      return cached;
    }

    final response = await _channel.invokeMethod<Uint8List>(
      'loadDocumentThumbnail',
      <String, dynamic>{
        'documentUri': documentUri,
        'width': width,
        'height': height,
      },
    );
    if (response != null && response.isNotEmpty) {
      _thumbnailCache[documentUri] = response;
    }
    return response;
  }

  Future<bool> deleteDocument({required String documentUri}) async {
    final response = await _channel.invokeMethod<bool>(
      'deleteDocument',
      <String, dynamic>{'documentUri': documentUri},
    );
    return response ?? false;
  }
}
