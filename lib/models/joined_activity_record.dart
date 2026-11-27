import 'activity_record.dart';

enum JoinedEnrollmentStatus {
  confirmed('CONFIRMED'),
  pendingJoin('PENDING_JOIN'),
  pendingLeave('PENDING_LEAVE');

  const JoinedEnrollmentStatus(this.databaseValue);

  final String databaseValue;

  static JoinedEnrollmentStatus fromDatabase(String value) {
    return JoinedEnrollmentStatus.values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => throw FormatException(
        'Unknown joined activity enrollment status: $value',
      ),
    );
  }
}

enum JoinedSyncStatus {
  synced('SYNCED'),
  pending('PENDING'),
  processing('PROCESSING'),
  failed('FAILED');

  const JoinedSyncStatus(this.databaseValue);

  final String databaseValue;

  static JoinedSyncStatus fromDatabase(String value) {
    return JoinedSyncStatus.values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () =>
          throw FormatException('Unknown joined activity sync status: $value'),
    );
  }
}

class JoinedActivityRecord {
  const JoinedActivityRecord({
    required this.activity,
    required this.userId,
    required this.enrollmentStatus,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    this.enrollmentId,
    this.joinedAt,
    this.syncedAt,
    this.lastError,
  });

  final ActivityRecord activity;
  final String userId;
  final JoinedEnrollmentStatus enrollmentStatus;
  final JoinedSyncStatus syncStatus;
  final String? enrollmentId;
  final DateTime? joinedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;
  final String? lastError;

  bool get isPendingJoin =>
      enrollmentStatus == JoinedEnrollmentStatus.pendingJoin;

  bool get isPendingLeave =>
      enrollmentStatus == JoinedEnrollmentStatus.pendingLeave;

  bool get isPast {
    final end = DateTime.tryParse(activity.endTime);
    return end != null && !end.isAfter(DateTime.now());
  }

  JoinedActivityRecord copyWith({
    DateTime? updatedAt,
    JoinedSyncStatus? syncStatus,
    String? lastError,
    bool clearLastError = false,
  }) {
    return JoinedActivityRecord(
      activity: activity,
      userId: userId,
      enrollmentStatus: enrollmentStatus,
      syncStatus: syncStatus ?? this.syncStatus,
      enrollmentId: enrollmentId,
      joinedAt: joinedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'user_id': userId,
      'activity_id': activity.id,
      'enrollment_status': enrollmentStatus.databaseValue,
      'sync_status': syncStatus.databaseValue,
      'enrollment_id': enrollmentId,
      'joined_at': joinedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'synced_at': syncedAt?.toUtc().toIso8601String(),
      'last_error': lastError,
    };
  }

  factory JoinedActivityRecord.fromDatabaseMap(Map<String, Object?> map) {
    return JoinedActivityRecord(
      activity: ActivityRecord.fromMap(map),
      userId: map['joined_user_id'] as String,
      enrollmentStatus: JoinedEnrollmentStatus.fromDatabase(
        map['joined_enrollment_status'] as String,
      ),
      syncStatus: JoinedSyncStatus.fromDatabase(
        map['joined_sync_status'] as String,
      ),
      enrollmentId: map['joined_enrollment_id'] as String?,
      joinedAt: _dateTime(map['joined_at'] as String?),
      createdAt: DateTime.parse(map['joined_created_at'] as String),
      updatedAt: DateTime.parse(map['joined_updated_at'] as String),
      syncedAt: _dateTime(map['joined_synced_at'] as String?),
      lastError: map['joined_last_error'] as String?,
    );
  }

  factory JoinedActivityRecord.fromRemoteJson(
    Object? value, {
    required String userId,
    DateTime? syncedAt,
  }) {
    if (value is! Map) {
      throw const FormatException('Invalid joined activity response item.');
    }

    final activityJson = value['activity'];
    final enrollmentJson = value['enrollment'];
    if (activityJson is! Map || enrollmentJson is! Map) {
      throw const FormatException(
        'Joined activity response is missing activity or enrollment.',
      );
    }

    final activityMap = Map<String, dynamic>.from(activityJson);
    if (activityMap['joined'] != true) {
      throw const FormatException(
        'Joined activity response contains an unjoined activity.',
      );
    }

    final enrollment = Map<String, dynamic>.from(enrollmentJson);
    final status = enrollment['status'];
    final id = enrollment['id'];
    final joinedAt = enrollment['joinedAt'];
    if (status != 'CONFIRMED' || id is! String || joinedAt is! String) {
      throw const FormatException('Invalid joined activity enrollment.');
    }

    final parsedJoinedAt = DateTime.tryParse(joinedAt);
    if (parsedJoinedAt == null) {
      throw const FormatException('Invalid joined activity timestamp.');
    }

    final now = (syncedAt ?? DateTime.now()).toUtc();
    return JoinedActivityRecord(
      activity: ActivityRecord.fromJson(activityMap, cachedAt: now),
      userId: userId,
      enrollmentStatus: JoinedEnrollmentStatus.confirmed,
      syncStatus: JoinedSyncStatus.synced,
      enrollmentId: id,
      joinedAt: parsedJoinedAt.toUtc(),
      createdAt: now,
      updatedAt: now,
      syncedAt: now,
    );
  }

  static DateTime? _dateTime(String? value) {
    if (value == null) return null;
    return DateTime.parse(value);
  }
}
