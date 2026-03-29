import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalekopro_farma_flutter/core/storage/saf_bridge.dart';
import 'package:dalekopro_farma_flutter/features/upload/presentation/saf_image_picker_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SAF picker sorts by modified newest first and returns selection', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    SafImageEntry? selectedImage;
    final bridge = _FakeSafBridge(
      thumbnails: <String, Uint8List?>{
        'content://images/newest': Uint8List.fromList(const <int>[1, 2, 3]),
        'content://images/older': Uint8List.fromList(const <int>[4, 5, 6]),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    selectedImage = await Navigator.of(context).push<SafImageEntry>(
                      MaterialPageRoute(
                        builder: (_) => SafImagePickerScreen(
                          safBridge: bridge,
                          images: const <SafImageEntry>[
                            SafImageEntry(
                              uri: 'content://images/second-newest',
                              displayName: 'second-newest.jpg',
                              mimeType: 'image/jpeg',
                              lastModifiedMillis: 1900,
                            ),
                            SafImageEntry(
                              uri: 'content://images/older',
                              displayName: 'older.jpg',
                              mimeType: 'image/jpeg',
                              lastModifiedMillis: 1000,
                            ),
                            SafImageEntry(
                              uri: 'content://images/newest',
                              displayName: 'newest.jpg',
                              mimeType: 'image/jpeg',
                              lastModifiedMillis: 2000,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Sortiranje: Modified (newest first)'), findsOneWidget);
    expect(find.byType(GridView), findsWidgets);
    expect(find.text('01.01.1970'), findsOneWidget);

    final firstCard = find.byKey(
      const ValueKey('saf-image-content://images/newest'),
    );
    final secondCardSameRow = find.byKey(
      const ValueKey('saf-image-content://images/second-newest'),
    );
    final olderCard = find.byKey(
      const ValueKey('saf-image-content://images/older'),
    );
    expect(firstCard, findsOneWidget);
    expect(secondCardSameRow, findsOneWidget);
    expect(olderCard, findsOneWidget);
    expect(
      tester.getTopLeft(firstCard).dy,
      equals(tester.getTopLeft(secondCardSameRow).dy),
    );
    expect(find.text('newest.jpg'), findsNothing);
    expect(find.textContaining('Modified:'), findsNothing);
    expect(find.textContaining('Size:'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('saf-image-content://images/newest')));
    await tester.pumpAndSettle();

    expect(navigatorKey.currentState!.canPop(), isFalse);
    expect(selectedImage?.uri, 'content://images/newest');
  });

  testWidgets('SAF picker shows placeholder when thumbnail is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SafImagePickerScreen(
          safBridge: _FakeSafBridge(thumbnails: <String, Uint8List?>{}),
          images: const <SafImageEntry>[
            SafImageEntry(
              uri: 'content://images/missing',
              displayName: 'missing.jpg',
              mimeType: 'image/jpeg',
              lastModifiedMillis: 1000,
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Nema previewa'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.text('01.01.1970'), findsOneWidget);
  });

  testWidgets('SAF picker uses cached thumbnail without lazy loading call', (
    tester,
  ) async {
    final bridge = _FakeSafBridge(
      thumbnails: <String, Uint8List?>{
        'content://images/cached': Uint8List.fromList(const <int>[9, 9, 9]),
      },
    );
    bridge.cacheThumbnail(
      documentUri: 'content://images/cached',
      bytes: Uint8List.fromList(const <int>[9, 9, 9]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SafImagePickerScreen(
          safBridge: bridge,
          images: const <SafImageEntry>[
            SafImageEntry(
              uri: 'content://images/cached',
              displayName: 'cached.jpg',
              mimeType: 'image/jpeg',
              lastModifiedMillis: 1000,
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(bridge.thumbnailLoadCount, 0);
  });

  testWidgets('SAF picker groups images by date and puts unknown date last', (
    tester,
  ) async {
    final screen = SafImagePickerScreen(
      safBridge: _FakeSafBridge(thumbnails: <String, Uint8List?>{}),
      images: const <SafImageEntry>[
        SafImageEntry(
          uri: 'content://images/day-two',
          displayName: 'day-two.jpg',
          mimeType: 'image/jpeg',
          lastModifiedMillis: 86400000,
        ),
        SafImageEntry(
          uri: 'content://images/day-one-a',
          displayName: 'day-one-a.jpg',
          mimeType: 'image/jpeg',
          lastModifiedMillis: 1000,
        ),
        SafImageEntry(
          uri: 'content://images/day-one-b',
          displayName: 'day-one-b.jpg',
          mimeType: 'image/jpeg',
          lastModifiedMillis: 2000,
        ),
        SafImageEntry(
          uri: 'content://images/unknown',
          displayName: 'unknown.jpg',
          mimeType: 'image/jpeg',
        ),
      ],
    );

    expect(
      SafImagePickerScreen.buildSections(screen.images)
          .map((section) => section.title)
          .toList(),
      <String>['02.01.1970', '01.01.1970', 'Nepoznat datum'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: screen,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('02.01.1970'), findsOneWidget);
    expect(find.text('01.01.1970'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Nepoznat datum'),
      300,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('Nepoznat datum'), findsOneWidget);
  });

  testWidgets('SAF picker long press opens delete options and removes image', (
    tester,
  ) async {
    final bridge = _FakeSafBridge(
      thumbnails: <String, Uint8List?>{},
      deleteResult: true,
    );
    bridge.cacheImagesForTree(
      treeUri: 'content://tree/1',
      images: const <SafImageEntry>[
        SafImageEntry(
          uri: 'content://images/delete-me',
          displayName: 'delete-me.jpg',
          mimeType: 'image/jpeg',
          lastModifiedMillis: 1000,
        ),
      ],
    );
    bridge.cacheThumbnail(
      documentUri: 'content://images/delete-me',
      bytes: Uint8List.fromList(const <int>[1, 2, 3]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SafImagePickerScreen(
          safBridge: bridge,
          images: const <SafImageEntry>[
            SafImageEntry(
              uri: 'content://images/delete-me',
              displayName: 'delete-me.jpg',
              mimeType: 'image/jpeg',
              lastModifiedMillis: 1000,
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey('saf-image-content://images/delete-me')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Obrisati sliku?'), findsOneWidget);

    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(bridge.deletedUris, <String>['content://images/delete-me']);
    expect(
      find.byKey(const ValueKey('saf-image-content://images/delete-me')),
      findsNothing,
    );
    expect(
      find.text('U odabranom SAF folderu nema dostupnih slika.'),
      findsOneWidget,
    );
    expect(
      bridge.getCachedThumbnail(documentUri: 'content://images/delete-me'),
      isNull,
    );
  });

  testWidgets('SAF picker keeps image when delete fails', (tester) async {
    final bridge = _FakeSafBridge(
      thumbnails: <String, Uint8List?>{},
      deleteResult: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SafImagePickerScreen(
          safBridge: bridge,
          images: const <SafImageEntry>[
            SafImageEntry(
              uri: 'content://images/fail',
              displayName: 'fail.jpg',
              mimeType: 'image/jpeg',
              lastModifiedMillis: 1000,
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey('saf-image-content://images/fail')),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(bridge.deletedUris, <String>['content://images/fail']);
    expect(find.text('Sliku nije moguce obrisati.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('saf-image-content://images/fail')),
      findsOneWidget,
    );
  });
}

class _FakeSafBridge extends SafBridge {
  _FakeSafBridge({
    required this.thumbnails,
    this.deleteResult = false,
  });

  final Map<String, Uint8List?> thumbnails;
  final bool deleteResult;
  int thumbnailLoadCount = 0;
  final List<String> deletedUris = <String>[];

  @override
  Future<Uint8List?> loadDocumentThumbnail({
    required String documentUri,
    int width = 512,
    int height = 512,
  }) async {
    thumbnailLoadCount++;
    return thumbnails[documentUri];
  }

  @override
  Future<bool> deleteDocument({required String documentUri}) async {
    deletedUris.add(documentUri);
    return deleteResult;
  }
}
