import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart' show DatabaseException;

import '../models/storage_capacity.dart';
import 'storage_capacity_service.dart';

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
      } on FileSystemException catch (error, stackTrace) {
        _reportError(step.name, error, stackTrace);
      } on DatabaseException catch (error, stackTrace) {
        _reportError(step.name, error, stackTrace);
      } on PlatformException catch (error, stackTrace) {
        _reportError(step.name, error, stackTrace);
      } on MissingPluginException catch (error, stackTrace) {
        _reportError(step.name, error, stackTrace);
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
