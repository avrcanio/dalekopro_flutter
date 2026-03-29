import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/saf_bridge.dart';
import '../../../core/widgets/status_widgets.dart';

class SafImagePickerScreen extends StatefulWidget {
  const SafImagePickerScreen({
    super.key,
    required this.images,
    this.safBridge,
  });

  final List<SafImageEntry> images;
  final SafBridge? safBridge;

  static final DateFormat sectionDateFormat = DateFormat('dd.MM.yyyy');

  static List<SafImageEntry> sortImages(List<SafImageEntry> images) {
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

  static List<SafImageSection> buildSections(List<SafImageEntry> images) {
    final sorted = sortImages(images);
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
          : sectionDateFormat.format(DateTime.fromMillisecondsSinceEpoch(millis));

      if (!sectionsByKey.containsKey(key)) {
        sectionsByKey[key] = <SafImageEntry>[];
        labels[key] = label;
        order.add(key);
      }
      sectionsByKey[key]!.add(item);
    }

    return order
        .map(
          (key) => SafImageSection(
            title: labels[key]!,
            items: List<SafImageEntry>.unmodifiable(sectionsByKey[key]!),
          ),
        )
        .toList(growable: false);
  }

  @override
  State<SafImagePickerScreen> createState() => _SafImagePickerScreenState();
}

class _SafImagePickerScreenState extends State<SafImagePickerScreen> {
  late final SafBridge _bridge;
  late List<SafImageEntry> _images;
  bool _deletingImage = false;
  String? _message;
  StatusType _messageType = StatusType.info;

  List<SafImageSection> get sections => SafImagePickerScreen.buildSections(_images);

  @override
  void initState() {
    super.initState();
    _bridge = widget.safBridge ?? const SafBridge();
    _images = List<SafImageEntry>.of(widget.images);
  }

  void _setMessage(String message, StatusType type) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageType = type;
    });
  }

  Future<void> _showImageOptions(SafImageEntry item) async {
    if (_deletingImage) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(context).pop('cancel'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action != 'delete') {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Obrisati sliku?'),
          content: const Text('Slika ce biti obrisana s telefona.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _deletingImage = true;
      _message = null;
    });

    try {
      final deleted = await _bridge.deleteDocument(documentUri: item.uri);
      if (!mounted) return;

      if (deleted) {
        _bridge.removeDocumentFromCache(documentUri: item.uri);
        setState(() {
          _images = _images.where((image) => image.uri != item.uri).toList();
        });
        _setMessage('Slika je obrisana s telefona.', StatusType.success);
      } else {
        _setMessage('Sliku nije moguce obrisati.', StatusType.warning);
      }
    } on PlatformException {
      _setMessage('Sliku nije moguce obrisati.', StatusType.error);
    } finally {
      if (mounted) {
        setState(() {
          _deletingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Odabir slike iz SAF foldera')),
      body: SafeArea(
        top: false,
        child: _images.isEmpty
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
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: InlineStatusMessage(
                        message: _message!,
                        type: _messageType,
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
                                    bridge: _bridge,
                                    deleting: _deletingImage,
                                    onTap: () => Navigator.of(context).pop(item),
                                    onLongPress: () => _showImageOptions(item),
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

class SafImageSection {
  const SafImageSection({
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
    required this.onLongPress,
    required this.deleting,
  });

  final SafImageEntry item;
  final SafBridge bridge;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cachedBytes = bridge.getCachedThumbnail(documentUri: item.uri);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: InkWell(
        onTap: deleting ? null : onTap,
        onLongPress: deleting ? null : onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: cachedBytes != null && cachedBytes.isNotEmpty
                  ? Image.memory(
                      cachedBytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _SafThumbnailPlaceholder(),
                    )
                  : FutureBuilder<Uint8List?>(
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
            if (deleting)
              ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
