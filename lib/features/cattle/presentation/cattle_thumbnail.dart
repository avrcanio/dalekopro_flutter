import 'package:flutter/material.dart';

import '../../../core/widgets/app_cached_network_image.dart';

/// Kvadratni thumbnail kao na listi goveda (leading u ListTile).
class CattleThumbnail extends StatelessWidget {
  const CattleThumbnail({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    const width = 48.0;
    const height = 64.0;

    if (imageUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AppCachedNetworkImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          placeholder: Container(
            width: width,
            height: height,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          errorBuilder: const _CattleThumbnailFallback(),
        ),
      );
    }

    return const _CattleThumbnailFallback();
  }
}

class _CattleThumbnailFallback extends StatelessWidget {
  const _CattleThumbnailFallback();

  @override
  Widget build(BuildContext context) {
    const width = 48.0;
    const height = 64.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.pets_outlined),
    );
  }
}
