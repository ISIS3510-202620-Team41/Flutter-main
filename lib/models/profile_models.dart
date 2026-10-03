class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.bio,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String name;
  final String bio;
  final String? avatarUrl;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        json['email'] is! String ||
        json['name'] is! String) {
      throw const FormatException('El perfil recibido no es válido.');
    }
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      bio: json['bio'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class FreeInterval {
  const FreeInterval({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  factory FreeInterval.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['start'] as String? ?? '');
    final end = DateTime.tryParse(json['end'] as String? ?? '');
    if (start == null || end == null) {
      throw const FormatException('Intervalo de horario inválido.');
    }
    return FreeInterval(start: start, end: end);
  }
}

class DayGaps {
  const DayGaps({required this.date, required this.timezone, required this.free});

  final DateTime date;
  final String timezone;
  final List<FreeInterval> free;

  factory DayGaps.fromJson(Map<String, dynamic> json) {
    final rawFree = json['free'];
    if (json['date'] is! String || json['timezone'] is! String || rawFree is! List) {
      throw const FormatException('La respuesta del horario no es válida.');
    }
    final date = DateTime.tryParse(json['date'] as String);
    if (date == null) {
      throw const FormatException('La fecha del horario no es válida.');
    }
    return DayGaps(
      date: date,
      timezone: json['timezone'] as String,
      free: rawFree
          .map((item) => FreeInterval.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
    );
  }
}

class GoogleSyncResult {
  const GoogleSyncResult({
    required this.imported,
    required this.skippedEvents,
    required this.calendars,
  });

  final int imported;
  final int skippedEvents;
  final int calendars;

  factory GoogleSyncResult.fromJson(Map<String, dynamic> json) {
    return GoogleSyncResult(
      imported: json['imported'] as int? ?? 0,
      skippedEvents: json['skippedEvents'] as int? ?? 0,
      calendars: json['calendars'] as int? ?? 0,
    );
  }
}

class GoogleConnectionStatus {
  const GoogleConnectionStatus({required this.connected});

  final bool connected;

  factory GoogleConnectionStatus.fromJson(Map<String, dynamic> json) {
    if (json['connected'] is! bool) {
      throw const FormatException('El estado de Google Calendar no es válido.');
    }
    return GoogleConnectionStatus(connected: json['connected'] as bool);
  }
}
