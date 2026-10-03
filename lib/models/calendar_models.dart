enum CalendarConnectionStatus {
  disconnected,
  connecting,
  connected,
  syncing,
  error,
}

class CalendarConnection {
  const CalendarConnection({
    required this.status,
    this.email,
    this.lastSyncedAt,
    this.errorMessage,
  });

  const CalendarConnection.disconnected()
    : this(status: CalendarConnectionStatus.disconnected);

  final CalendarConnectionStatus status;
  final String? email;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  CalendarConnection copyWith({
    CalendarConnectionStatus? status,
    String? email,
    DateTime? lastSyncedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CalendarConnection(
      status: status ?? this.status,
      email: email ?? this.email,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  factory CalendarConnection.fromJson(Map<String, dynamic> json) {
    final connected = json['connected'] == true;
    return CalendarConnection(
      status: connected
          ? CalendarConnectionStatus.connected
          : CalendarConnectionStatus.disconnected,
      email: json['email'] as String?,
      lastSyncedAt: _parseDate(json['lastSyncedAt']),
    );
  }
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.location,
    this.allDay = false,
    this.source = 'google',
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? location;
  final bool allDay;
  final String source;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final startsAt = _parseDate(json['startsAt']);
    final endsAt = _parseDate(json['endsAt']);
    if (json['id'] is! String ||
        json['title'] is! String ||
        startsAt == null ||
        endsAt == null) {
      throw const FormatException('Evento de calendario inválido.');
    }
    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      startsAt: startsAt,
      endsAt: endsAt,
      location: json['location'] as String?,
      allDay: json['allDay'] == true,
      source: json['source'] as String? ?? 'google',
    );
  }
}

class CalendarSyncResult {
  const CalendarSyncResult({
    required this.connection,
    required this.events,
  });

  final CalendarConnection connection;
  final List<CalendarEvent> events;

  factory CalendarSyncResult.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'];
    if (rawEvents is! List) {
      throw const FormatException('La respuesta no contiene eventos.');
    }
    return CalendarSyncResult(
      connection: CalendarConnection.fromJson(json),
      events: rawEvents
          .map(
            (event) => CalendarEvent.fromJson(
              Map<String, dynamic>.from(event as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}
