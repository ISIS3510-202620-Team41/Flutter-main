enum AvatarUploadStatus { pending, processing, failed }

class PendingAvatarUpload {
  const PendingAvatarUpload({
    required this.id,
    required this.userId,
    required this.localPath,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
  });

  final String id;
  final String userId;
  final String localPath;
  final AvatarUploadStatus status;
  final int attemptCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PendingAvatarUpload.fromMap(Map<String, Object?> map) {
    return PendingAvatarUpload(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      localPath: map['local_path'] as String,
      status: AvatarUploadStatus.values.byName(
        (map['status'] as String).toLowerCase(),
      ),
      attemptCount: (map['attempt_count'] as num).toInt(),
      lastError: map['last_error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'local_path': localPath,
      'status': status.name.toUpperCase(),
      'attempt_count': attemptCount,
      'last_error': lastError,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  PendingAvatarUpload copyWith({
    AvatarUploadStatus? status,
    int? attemptCount,
    String? lastError,
    bool clearLastError = false,
    DateTime? updatedAt,
  }) {
    return PendingAvatarUpload(
      id: id,
      userId: userId,
      localPath: localPath,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
