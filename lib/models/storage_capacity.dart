enum StorageCapacityStatus { sufficient, insufficient, unavailable }

enum StorageFailureKind {
  capacity,
  sqlite,
  fileSystem,
  platform,
  provider,
  unexpected,
}

class StorageCapacity {
  const StorageCapacity({
    required this.status,
    required this.availableBytes,
    required this.requiredFreeBytes,
    this.errorMessage,
    this.failureKind,
  });

  final StorageCapacityStatus status;
  final int? availableBytes;
  final int requiredFreeBytes;
  final String? errorMessage;
  final StorageFailureKind? failureKind;

  bool get canWriteOptionalData => status == StorageCapacityStatus.sufficient;

  bool get hasCapacityInformation =>
      status != StorageCapacityStatus.unavailable;
}
