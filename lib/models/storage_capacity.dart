enum StorageCapacityStatus { sufficient, insufficient, unavailable }

class StorageCapacity {
  const StorageCapacity({
    required this.status,
    required this.availableBytes,
    required this.requiredFreeBytes,
    this.errorMessage,
  });

  final StorageCapacityStatus status;
  final int? availableBytes;
  final int requiredFreeBytes;
  final String? errorMessage;

  bool get canWriteOptionalData => status == StorageCapacityStatus.sufficient;

  bool get hasCapacityInformation =>
      status != StorageCapacityStatus.unavailable;
}
