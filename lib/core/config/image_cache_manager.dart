import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppImageCacheManager {
  AppImageCacheManager._();

  static const String _cacheKey = 'dalekopro_cattle_images_v1';

  static final CacheManager instance = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 400,
      repo: JsonCacheInfoRepository(databaseName: _cacheKey),
    ),
  );
}
