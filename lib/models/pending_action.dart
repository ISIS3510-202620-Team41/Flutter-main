import 'dart:convert';

enum PendingActionType {
  joinActivity,
  leaveActivity,
  createActivity,
}

enum PendingActionStatus {
  pending,
  processing,
  failed,
  completed,
}

class PendingAction {
  const PendingAction({
    required this.id,
    required this.userId,
    required this.type,
    required this.activityId,
    required this.payload,
    required this.status,
    required this.attempts,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
  });

  final String id;
  final String userId;
  final PendingActionType type;
  final String activityId;

  // Parametros originales de la peticion
  final Map<String, dynamic> payload;

  final PendingActionStatus status;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PendingAction.fromMap(Map<String, Object?> map) {
    return PendingAction(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: PendingActionType.values.byName(
        _typeFromDatabase(map['action_type'] as String),
      ),
      activityId: map['activity_id'] as String,
      payload: Map<String, dynamic>.from(
        jsonDecode(map['payload_json'] as String) as Map,
      ),
      status: PendingActionStatus.values.byName(
        (map['status'] as String).toLowerCase(),
      ),
      attempts: (map['attempts'] as num).toInt(),
      lastError: map['last_error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'action_type': _typeToDatabase(type),
      'activity_id': activityId,
      'payload_json': jsonEncode(payload),
      'status': status.name.toUpperCase(),
      'attempts': attempts,
      'last_error': lastError,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  PendingAction copyWith({PendingActionStatus? status, int? attempts, String? lastError, bool clearLastError = false, DateTime? updatedAt,}) {
    return PendingAction(
      id: id,
      userId: userId,
      type: type,
      activityId: activityId,
      payload: payload,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _typeToDatabase(PendingActionType type) {
    switch (type) {
      case PendingActionType.joinActivity:
        return 'JOIN_ACTIVITY';
      case PendingActionType.leaveActivity:
        return 'LEAVE_ACTIVITY';
      case PendingActionType.createActivity:
        return 'CREATE_ACTIVITY';
    }
  }

  static String _typeFromDatabase(String type) {
    switch (type) {
      case 'JOIN_ACTIVITY':
        return 'joinActivity';
      case 'LEAVE_ACTIVITY':
        return 'leaveActivity';
      case 'CREATE_ACTIVITY':
        return 'createActivity';
      default:
        throw FormatException('Unknown pending action type: $type');
    }
  }
}
