import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:llamalla/services/activity_image_cache_service.dart';
import 'package:llamalla/services/storage_capacity_service.dart';
import 'package:llamalla/services/storage_cleanup_service.dart';

void main() {
  late Directory supportDirectory;
  late StorageCapacityService capacityService;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'llamalla-image-cache-test-',
    );
    capacityService = StorageCapacityService(
      readAvailableBytes: () async => 5,
      minimumFreeBytes: 10,
      safetyMarginBytes: 5,
    );
  });

  tearDown(() async {
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test('skips an optional image write when capacity is insufficient', () async {
    final service = ActivityImageCacheService(
      capacityService: capacityService,
      cleanupService: StorageCleanupService(
        capacityService: capacityService,
        steps: const [],
      ),
      loadImage: (_) async => http.Response(
        'image bytes',
        200,
        headers: const {'content-type': 'image/png'},
      ),
      getSupportDirectory: () async => supportDirectory,
    );

    final path = await service.downloadAndCache(
      activityId: 'activity-1',
      imageUrl: 'https://example.test/activity.png',
    );

    expect(path, isNull);
    expect(supportDirectory.listSync(), isEmpty);
  });

  test('cleans regenerable caches and retries an image write', () async {
    var availableBytes = 5;
    var cleanups = 0;
    final serviceCapacity = StorageCapacityService(
      readAvailableBytes: () async => availableBytes,
      minimumFreeBytes: 10,
      safetyMarginBytes: 5,
    );
    final service = ActivityImageCacheService(
      capacityService: serviceCapacity,
      cleanupService: StorageCleanupService(
        capacityService: serviceCapacity,
        steps: [
          StorageCleanupStep(
            name: 'old images',
            cleanup: () async {
              cleanups++;
              availableBytes = 100;
            },
          ),
        ],
      ),
      loadImage: (_) async => http.Response(
        'image bytes',
        200,
        headers: const {'content-type': 'image/png'},
      ),
      getSupportDirectory: () async => supportDirectory,
    );

    final path = await service.downloadAndCache(
      activityId: 'activity-1',
      imageUrl: 'https://example.test/activity.png',
    );

    expect(cleanups, 1);
    expect(path, isNotNull);
    expect(await File(path!).exists(), isTrue);
  });

  test('reports filesystem failures without throwing to the caller', () async {
    final blockingFile = File('${supportDirectory.path}\\not-a-directory');
    await blockingFile.writeAsString('occupied');
    final reportedErrors = <Object>[];

    final service = ActivityImageCacheService(
      capacityService: StorageCapacityService(
        readAvailableBytes: () async => 100,
        minimumFreeBytes: 0,
        safetyMarginBytes: 0,
      ),
      loadImage: (_) async => http.Response(
        'image bytes',
        200,
        headers: const {'content-type': 'image/png'},
      ),
      getSupportDirectory: () async => Directory(blockingFile.path),
      reportError: (error, _) => reportedErrors.add(error),
    );

    final path = await service.downloadAndCache(
      activityId: 'activity-1',
      imageUrl: 'https://example.test/activity.png',
    );

    expect(path, isNull);
    expect(reportedErrors, hasLength(1));
    expect(reportedErrors.single, isA<FileSystemException>());
  });
}
