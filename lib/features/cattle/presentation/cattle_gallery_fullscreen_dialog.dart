import 'package:flutter/material.dart';

import '../../../core/widgets/app_cached_network_image.dart';

/// Puni zaslon: carousel slika, pinch zoom, X za zatvaranje.
void showCattleGalleryFullscreenDialog(
  BuildContext context, {
  required List<String> urls,
  required String subtitle,
}) {
  if (urls.isEmpty) {
    return;
  }
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    useSafeArea: false,
    builder: (ctx) => CattleGalleryFullscreenDialog(
      urls: urls,
      subtitle: subtitle,
    ),
  );
}

class CattleGalleryFullscreenDialog extends StatefulWidget {
  const CattleGalleryFullscreenDialog({
    super.key,
    required this.urls,
    required this.subtitle,
  });

  final List<String> urls;
  final String subtitle;

  @override
  State<CattleGalleryFullscreenDialog> createState() =>
      _CattleGalleryFullscreenDialogState();
}

class _CattleGalleryFullscreenDialogState
    extends State<CattleGalleryFullscreenDialog> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.urls.length;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: n,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final url = widget.urls[i];
              return ColoredBox(
                color: Colors.black,
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.6,
                    maxScale: 4,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return AppCachedNetworkImage(
                          imageUrl: url,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          fit: BoxFit.contain,
                          placeholder: const SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                              strokeWidth: 2,
                            ),
                          ),
                          errorBuilder: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white38,
                            size: 64,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, left: 8),
                      child: Text(
                        widget.subtitle.trim().isEmpty
                            ? 'Pregled slika'
                            : widget.subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Zatvori',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (n > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Text(
                '${_index + 1} / $n',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
