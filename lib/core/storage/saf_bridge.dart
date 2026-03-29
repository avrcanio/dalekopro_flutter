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

    return (response ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(SafImageEntry.fromMap)
        .where((item) => item.uri.isNotEmpty)
        .toList(growable: false);
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
    final response = await _channel.invokeMethod<Uint8List>(
      'loadDocumentThumbnail',
      <String, dynamic>{
        'documentUri': documentUri,
        'width': width,
        'height': height,
      },
    );
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
