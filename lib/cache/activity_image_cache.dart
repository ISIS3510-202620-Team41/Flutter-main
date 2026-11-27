import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/foundation.dart';

import '../services/storage_capacity_service.dart';

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
    final capacity = await StorageCapacityService().check();
    if (!capacity.canWriteOptionalData) {
      if (!capacity.hasCapacityInformation) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: StateError(
              capacity.errorMessage ?? 'Unable to check storage capacity.',
            ),
            stack: StackTrace.current,
            library: 'activity image cache',
          ),
        );
      }
      return;
    }

    for (final url in urls) {
      if (url.isEmpty) continue;
      try {
        await instance.getSingleFile(url);
      } on FileSystemException catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'activity image cache',
          ),
        );
      } on Exception catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'activity image cache',
          ),
        );
      }
    }
  }
}
