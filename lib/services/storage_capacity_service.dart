import 'package:storage_space/storage_space.dart';

import '../models/storage_capacity.dart';
import 'storage_write_error.dart';

typedef AvailableStorageReader = Future<int> Function();

class StorageCapacityService {
  static final shared = StorageCapacityService._shared();

  factory StorageCapacityService({
    AvailableStorageReader? readAvailableBytes,
    int minimumFreeBytes = defaultMinimumFreeBytes,
    int safetyMarginBytes = defaultSafetyMarginBytes,
    StorageFailureReporter? reportError,
  }) {
    if (readAvailableBytes == null &&
        minimumFreeBytes == defaultMinimumFreeBytes &&
        safetyMarginBytes == defaultSafetyMarginBytes &&
        reportError == null) {
      return shared;
    }
    return StorageCapacityService._(
      readAvailableBytes: readAvailableBytes ?? _readDeviceAvailableBytes,
      minimumFreeBytes: minimumFreeBytes,
      safetyMarginBytes: safetyMarginBytes,
      reportError: reportError ?? reportStorageFailure,
    );
  }

  StorageCapacityService._shared()
    : this._(
        readAvailableBytes: _readDeviceAvailableBytes,
        minimumFreeBytes: defaultMinimumFreeBytes,
        safetyMarginBytes: defaultSafetyMarginBytes,
        reportError: reportStorageFailure,
      );

  StorageCapacityService._({
    required this._readAvailableBytes,
    required this.minimumFreeBytes,
    required this.safetyMarginBytes,
    required this._reportError,
  }) {
    if (minimumFreeBytes < 0) {
      throw ArgumentError.value(minimumFreeBytes, 'minimumFreeBytes');
    }
    if (safetyMarginBytes < 0) {
      throw ArgumentError.value(safetyMarginBytes, 'safetyMarginBytes');
    }
  }

  static const int defaultMinimumFreeBytes = 100 * 1024 * 1024;
  static const int defaultSafetyMarginBytes = 20 * 1024 * 1024;

  final AvailableStorageReader _readAvailableBytes;
  final StorageFailureReporter _reportError;
  final int minimumFreeBytes;
  final int safetyMarginBytes;

  Future<StorageCapacity> check({int estimatedWriteBytes = 0}) async {
    if (estimatedWriteBytes < 0) {
      throw ArgumentError.value(estimatedWriteBytes, 'estimatedWriteBytes');
    }

    final requiredFreeBytes =
        minimumFreeBytes + safetyMarginBytes + estimatedWriteBytes;

    try {
      final availableBytes = await _readAvailableBytes();
      if (availableBytes < 0) {
        return StorageCapacity(
          status: StorageCapacityStatus.unavailable,
          availableBytes: null,
          requiredFreeBytes: requiredFreeBytes,
          errorMessage: 'The platform returned a negative storage value.',
          failureKind: StorageFailureKind.provider,
        );
      }

      return StorageCapacity(
        status: availableBytes >= requiredFreeBytes
            ? StorageCapacityStatus.sufficient
            : StorageCapacityStatus.insufficient,
        availableBytes: availableBytes,
        requiredFreeBytes: requiredFreeBytes,
      );
    } catch (error, stackTrace) {
      final classified = classifyStorageFailure(error);
      final failureKind = classified == StorageFailureKind.unexpected
          ? StorageFailureKind.provider
          : classified;
      _reportError(
        StorageWriteException(
          kind: failureKind,
          operation: 'capacity query',
          cause: error,
        ),
        stackTrace,
      );
      return _unavailable(requiredFreeBytes, error, failureKind);
    }
  }

  static Future<int> _readDeviceAvailableBytes() async {
    final storage = await getStorageSpace(
      lowOnSpaceThreshold: 0,
      fractionDigits: 0,
    );
    return storage.free;
  }

  StorageCapacity _unavailable(
    int requiredFreeBytes,
    Object error,
    StorageFailureKind failureKind,
  ) {
    return StorageCapacity(
      status: StorageCapacityStatus.unavailable,
      availableBytes: null,
      requiredFreeBytes: requiredFreeBytes,
      errorMessage: error.toString(),
      failureKind: failureKind,
    );
  }
}
