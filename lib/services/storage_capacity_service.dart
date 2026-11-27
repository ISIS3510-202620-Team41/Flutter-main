import 'package:flutter/services.dart';
import 'package:storage_space/storage_space.dart';

import '../models/storage_capacity.dart';

typedef AvailableStorageReader = Future<int> Function();

class StorageCapacityService {
  StorageCapacityService({
    AvailableStorageReader? readAvailableBytes,
    this.minimumFreeBytes = defaultMinimumFreeBytes,
    this.safetyMarginBytes = defaultSafetyMarginBytes,
  }) : _readAvailableBytes = readAvailableBytes ?? _readDeviceAvailableBytes {
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
        );
      }

      return StorageCapacity(
        status: availableBytes >= requiredFreeBytes
            ? StorageCapacityStatus.sufficient
            : StorageCapacityStatus.insufficient,
        availableBytes: availableBytes,
        requiredFreeBytes: requiredFreeBytes,
      );
    } on PlatformException catch (error) {
      return _unavailable(requiredFreeBytes, error);
    } on MissingPluginException catch (error) {
      return _unavailable(requiredFreeBytes, error);
    } on FormatException catch (error) {
      return _unavailable(requiredFreeBytes, error);
    }
  }

  static Future<int> _readDeviceAvailableBytes() async {
    final storage = await getStorageSpace(
      lowOnSpaceThreshold: 0,
      fractionDigits: 0,
    );
    return storage.free;
  }

  StorageCapacity _unavailable(int requiredFreeBytes, Object error) {
    return StorageCapacity(
      status: StorageCapacityStatus.unavailable,
      availableBytes: null,
      requiredFreeBytes: requiredFreeBytes,
      errorMessage: error.toString(),
    );
  }
}
