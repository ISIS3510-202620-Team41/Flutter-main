import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/models/storage_capacity.dart';
import 'package:llamalla/services/storage_capacity_service.dart';

void main() {
  group('StorageCapacityService', () {
    test(
      'allows optional writes when capacity meets the configured reserve',
      () async {
        final service = StorageCapacityService(
          readAvailableBytes: () async => 1_500,
          minimumFreeBytes: 1_000,
          safetyMarginBytes: 200,
        );

        final result = await service.check(estimatedWriteBytes: 300);

        expect(result.status, StorageCapacityStatus.sufficient);
        expect(result.availableBytes, 1_500);
        expect(result.requiredFreeBytes, 1_500);
        expect(result.canWriteOptionalData, isTrue);
      },
    );

    test('reports insufficient capacity below the reserve', () async {
      final service = StorageCapacityService(
        readAvailableBytes: () async => 1_499,
        minimumFreeBytes: 1_000,
        safetyMarginBytes: 200,
      );

      final result = await service.check(estimatedWriteBytes: 300);

      expect(result.status, StorageCapacityStatus.insufficient);
      expect(result.availableBytes, 1_499);
      expect(result.canWriteOptionalData, isFalse);
    });

    test(
      'reports platform query failures as unavailable with the cause',
      () async {
        final service = StorageCapacityService(
          readAvailableBytes: () async {
            throw PlatformException(
              code: 'storage_unavailable',
              message: 'Cannot read available storage',
            );
          },
          minimumFreeBytes: 100,
          safetyMarginBytes: 20,
        );

        final result = await service.check();

        expect(result.status, StorageCapacityStatus.unavailable);
        expect(result.availableBytes, isNull);
        expect(result.hasCapacityInformation, isFalse);
        expect(result.errorMessage, contains('Cannot read available storage'));
      },
    );

    test('rejects negative estimated write sizes', () async {
      final service = StorageCapacityService(
        readAvailableBytes: () async => 1_000,
      );

      await expectLater(
        service.check(estimatedWriteBytes: -1),
        throwsArgumentError,
      );
    });

    test('rejects negative configured limits', () {
      expect(
        () => StorageCapacityService(minimumFreeBytes: -1),
        throwsArgumentError,
      );
      expect(
        () => StorageCapacityService(safetyMarginBytes: -1),
        throwsArgumentError,
      );
    });
  });
}
