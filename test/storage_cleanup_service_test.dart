import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/models/storage_capacity.dart';
import 'package:llamalla/services/storage_capacity_service.dart';
import 'package:llamalla/services/storage_cleanup_service.dart';
import 'package:llamalla/services/storage_write_error.dart';

void main() {
  test('runs cleanup steps in order until the estimated write fits', () async {
    var availableBytes = 5;
    final attemptedSteps = <String>[];
    final service = StorageCleanupService(
      capacityService: StorageCapacityService(
        readAvailableBytes: () async => availableBytes,
        minimumFreeBytes: 10,
        safetyMarginBytes: 0,
      ),
      steps: [
        StorageCleanupStep(
          name: 'stale responses',
          cleanup: () async {
            attemptedSteps.add('stale responses');
            availableBytes = 9;
          },
        ),
        StorageCleanupStep(
          name: 'images',
          cleanup: () async {
            attemptedSteps.add('images');
            availableBytes = 12;
          },
        ),
        StorageCleanupStep(
          name: 'all responses',
          cleanup: () async {
            attemptedSteps.add('all responses');
            availableBytes = 100;
          },
        ),
      ],
    );

    final result = await service.makeRoomForOptionalWrite(
      estimatedWriteBytes: 2,
    );

    expect(result.status, StorageCapacityStatus.sufficient);
    expect(result.requiredFreeBytes, 12);
    expect(attemptedSteps, ['stale responses', 'images']);
  });

  test(
    'reports a cleanup failure and continues with later cache steps',
    () async {
      var availableBytes = 5;
      final reportedSteps = <String>[];
      final reportedFailures = <Object>[];
      final service = StorageCleanupService(
        capacityService: StorageCapacityService(
          readAvailableBytes: () async => availableBytes,
          minimumFreeBytes: 10,
          safetyMarginBytes: 0,
        ),
        steps: [
          StorageCleanupStep(
            name: 'managed images',
            cleanup: () async => throw const FileSystemException('disk full'),
          ),
          StorageCleanupStep(
            name: 'local images',
            cleanup: () async => throw StateError('unexpected cleanup failure'),
          ),
          StorageCleanupStep(
            name: 'later cache',
            cleanup: () async {
              availableBytes = 10;
            },
          ),
        ],
        reportError: (name, error, _) {
          reportedSteps.add(name);
          reportedFailures.add(error);
        },
      );

      final result = await service.makeRoomForOptionalWrite();

      expect(result.status, StorageCapacityStatus.sufficient);
      expect(reportedSteps, ['managed images', 'local images']);
      expect(
        reportedFailures.map(
          (failure) => (failure as StorageWriteException).kind,
        ),
        [StorageFailureKind.fileSystem, StorageFailureKind.unexpected],
      );
    },
  );

  test(
    'does not evict caches when the capacity query is unavailable',
    () async {
      var cleanupAttempted = false;
      final service = StorageCleanupService(
        capacityService: StorageCapacityService(
          readAvailableBytes: () async {
            throw PlatformException(code: 'storage_unavailable');
          },
          reportError: (_, _) {},
        ),
        steps: [
          StorageCleanupStep(
            name: 'images',
            cleanup: () async {
              cleanupAttempted = true;
            },
          ),
        ],
      );

      final result = await service.makeRoomForOptionalWrite();

      expect(result.status, StorageCapacityStatus.unavailable);
      expect(cleanupAttempted, isFalse);
    },
  );
}
