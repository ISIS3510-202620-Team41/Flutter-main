import 'package:flutter/foundation.dart';

import '../models/storage_capacity.dart';
import 'storage_capacity_service.dart';
import 'storage_write_error.dart';

typedef StorageCleanupErrorReporter =
    void Function(String stepName, Object error, StackTrace stackTrace);
typedef StorageCleanupCallback = Future<void> Function();

class StorageCleanupStep {
  const StorageCleanupStep({required this.name, required this.cleanup});

  final String name;
  final StorageCleanupCallback cleanup;
}

class StorageCleanupService {
  StorageCleanupService({
    required this.capacityService,
    required List<StorageCleanupStep> steps,
    StorageCleanupErrorReporter? reportError,
  }) : _steps = List.unmodifiable(steps),
       _reportError = reportError ?? _reportCleanupError;

  final StorageCapacityService capacityService;
  final List<StorageCleanupStep> _steps;
  final StorageCleanupErrorReporter _reportError;

  Future<StorageCapacity> makeRoomForOptionalWrite({
    int estimatedWriteBytes = 0,
  }) async {
    var capacity = await capacityService.check(
      estimatedWriteBytes: estimatedWriteBytes,
    );
    if (capacity.status != StorageCapacityStatus.insufficient) {
      return capacity;
    }

    for (final step in _steps) {
      try {
        await step.cleanup();
      } catch (error, stackTrace) {
        final failure = StorageWriteException(
          kind: classifyStorageFailure(error),
          operation: 'cleanup step "${step.name}"',
          cause: error,
        );
        _reportError(step.name, failure, stackTrace);
      }

      capacity = await capacityService.check(
        estimatedWriteBytes: estimatedWriteBytes,
      );
      if (capacity.status != StorageCapacityStatus.insufficient) {
        return capacity;
      }
    }

    return capacity;
  }

  static void _reportCleanupError(
    String stepName,
    Object error,
    StackTrace stackTrace,
  ) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'storage cache cleanup',
        context: ErrorDescription('While running cleanup step "$stepName".'),
      ),
    );
  }
}
