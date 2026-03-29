import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/saf_bridge.dart';
import '../../../core/widgets/status_widgets.dart';

class SafImagePickerScreen extends StatelessWidget {
  SafImagePickerScreen({
    super.key,
    required List<SafImageEntry> images,
    this.safBridge,
  }) : sections = _buildSections(images);

  final List<_SafImageSection> sections;
  final SafBridge? safBridge;

  static final DateFormat _sectionDateFormat = DateFormat('dd.MM.yyyy');

  static List<SafImageEntry> _sortImages(List<SafImageEntry> images) {
    final sorted = List<SafImageEntry>.of(images);
    sorted.sort((a, b) {
      final aModified = a.lastModifiedMillis;
      final bModified = b.lastModifiedMillis;
      if (aModified != null && bModified != null) {
        final compare = bModified.compareTo(aModified);
        if (compare != 0) return compare;
      } else if (aModified != null) {
        return -1;
      } else if (bModified != null) {
        return 1;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return sorted;
  }

  static List<_SafImageSection> _buildSections(List<SafImageEntry> images) {
    final sorted = _sortImages(images);
    final sectionsByKey = <String, List<SafImageEntry>>{};
    final labels = <String, String>{};
    final order = <String>[];

    for (final item in sorted) {
      final millis = item.lastModifiedMillis;
      final key = millis == null || millis <= 0
          ? 'unknown'
          : DateTime.fromMillisecondsSinceEpoch(millis).toIso8601String().split('T').first;
      final label = millis == null || millis <= 0
          ? 'Nepoznat datum'
          : _sectionDateFormat.format(DateTime.fromMillisecondsSinceEpoch(millis));

      if (!sectionsByKey.containsKey(key)) {
        sectionsByKey[key] = <SafImageEntry>[];
        labels[key] = label;
        order.add(key);
      }
      sectionsByKey[key]!.add(item);
    }

    return order
        .map(
          (key) => _SafImageSection(
            title: labels[key]!,
            items: List<SafImageEntry>.unmodifiable(sectionsByKey[key]!),
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final bridge = safBridge ?? const SafBridge();

    return Scaffold(
      appBar: AppBar(title: const Text('Odabir slike iz SAF foldera')),
      body: SafeArea(
        top: false,
        child: sections.isEmpty
            ? const FullScreenState(
                message: 'U odabranom SAF folderu nema dostupnih slika.',
                icon: Icons.photo_library_outlined,
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: InlineStatusMessage(
                      message: 'Sortiranje: Modified (newest first)',
                      type: StatusType.info,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == sections.length - 1 ? 0 : 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  section.title,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.92,
                                    ),
                                itemCount: section.items.length,
                                itemBuilder: (context, itemIndex) {
                                  final item = section.items[itemIndex];
                                  return _SafImageTile(
                                    key: ValueKey('saf-image-${item.uri}'),
                                    item: item,
                                    bridge: bridge,
                                    onTap: () => Navigator.of(context).pop(item),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SafImageSection {
  const _SafImageSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<SafImageEntry> items;
}

class _SafImageTile extends StatelessWidget {
  const _SafImageTile({
    super.key,
    required this.item,
    required this.bridge,
    required this.onTap,
  });

  final SafImageEntry item;
  final SafBridge bridge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: FutureBuilder<Uint8List?>(
            future: bridge.loadDocumentThumbnail(documentUri: item.uri),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final bytes = snapshot.data;
              if (bytes == null || bytes.isEmpty) {
                return const _SafThumbnailPlaceholder();
              }

              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _SafThumbnailPlaceholder(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SafThumbnailPlaceholder extends StatelessWidget {
  const _SafThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 42,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Nema previewa',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
