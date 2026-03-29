import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/core/storage/saf_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bridge = SafBridge();

  const channel = MethodChannel('dalekopro/saf');

  setUp(() {
    bridge.clearSessionCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'listImagesFromTree':
              return <Map<String, dynamic>>[
                <String, dynamic>{
                  'uri': 'content://images/2',
                  'displayName': 'newest.jpg',
                  'mimeType': 'image/jpeg',
                  'lastModifiedMillis': 2000,
                  'sizeBytes': 2048,
                },
                <String, dynamic>{
                  'uri': 'content://images/1',
                  'displayName': 'older.jpg',
                  'mimeType': 'image/jpeg',
                  'lastModifiedMillis': 1000,
                  'sizeBytes': 1024,
                },
              ];
            case 'copyDocumentToCache':
              return <String, dynamic>{
                'filePath': 'C:/temp/copied.jpg',
              };
            case 'loadDocumentThumbnail':
              return Uint8List.fromList(const <int>[1, 2, 3, 4]);
            case 'deleteDocument':
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    bridge.clearSessionCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('SafBridge maps listImagesFromTree response', () async {
    final images = await bridge.listImagesFromTree(treeUri: 'content://tree/1');

    expect(images, hasLength(2));
    expect(images.first.uri, 'content://images/2');
    expect(images.first.displayName, 'newest.jpg');
    expect(images.first.lastModifiedMillis, 2000);
    expect(images.first.sizeBytes, 2048);
  });

  test('SafBridge maps copyDocumentToCache response', () async {
    final path = await bridge.copyDocumentToCache(
      documentUri: 'content://images/2',
      suggestedFileName: 'newest.jpg',
    );

    expect(path, 'C:/temp/copied.jpg');
  });

  test('SafBridge maps loadDocumentThumbnail response', () async {
    final bytes = await bridge.loadDocumentThumbnail(
      documentUri: 'content://images/2',
    );

    expect(bytes, isNotNull);
    expect(bytes, orderedEquals(const <int>[1, 2, 3, 4]));
  });

  test('SafBridge maps deleteDocument response', () async {
    final deleted = await bridge.deleteDocument(
      documentUri: 'content://images/2',
    );

    expect(deleted, isTrue);
  });

  test('SafBridge caches image lists and thumbnails in memory', () async {
    final images = await bridge.listImagesFromTree(treeUri: 'content://tree/1');
    final cachedImages = bridge.getCachedImagesForTree(treeUri: 'content://tree/1');

    expect(cachedImages, isNotNull);
    expect(cachedImages, hasLength(images.length));

    final bytes = await bridge.loadDocumentThumbnail(
      documentUri: 'content://images/2',
    );
    final cachedBytes = bridge.getCachedThumbnail(
      documentUri: 'content://images/2',
    );

    expect(bytes, isNotNull);
    expect(cachedBytes, isNotNull);
    expect(cachedBytes, orderedEquals(const <int>[1, 2, 3, 4]));
  });
}
