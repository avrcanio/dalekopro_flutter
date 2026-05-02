import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/image_cache_manager.dart';

class AppCachedNetworkImage extends StatelessWidget {
  const AppCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.filterQuality,
    this.placeholder,
    this.errorBuilder,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  /// Ograničava dekodiranu širinu u memoriji (npr. širina × DPR za oštrinu bez punog megapiksela).
  final int? memCacheWidth;
  final int? memCacheHeight;
  final FilterQuality? filterQuality;
  final Widget? placeholder;
  final Widget? errorBuilder;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return errorBuilder ?? const SizedBox.shrink();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: AppImageCacheManager.instance,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      filterQuality: filterQuality ?? FilterQuality.low,
      placeholder: (_, __) => placeholder ?? const SizedBox.shrink(),
      errorWidget: (_, __, ___) => errorBuilder ?? const SizedBox.shrink(),
    );
  }
}
