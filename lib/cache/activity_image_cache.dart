import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// Disk cache for activity photos, used by CachedNetworkImage.
//Las fotos se almacenan como archivos,
class ActivityImageCacheManager {
  static const _key = 'activityImages';

  static final CacheManager instance = CacheManager(
    Config(
      _key,
      // Tras 30 días, una foto se considera «obsoleta»
      stalePeriod: const Duration(days: 30),
      // 100 archivos  Al superar este límite, se eliminan los archivos más antiguos.
      maxNrOfCacheObjects: 100,
    ),
  );

  //Descarga fotos en segundo plano para que estén en el disco
  static Future<void> prefetch(Iterable<String> urls) async {
    for (final url in urls) {
      if (url.isEmpty) continue;
      try {
        await instance.getSingleFile(url);
      } catch (_) {
      }
    }
  }
}