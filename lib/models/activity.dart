const activityCategoryLabels = ['Sports', 'Study', 'Culture', 'Entertainment'];

String categoryLabel(String? backendValue) {
  switch (backendValue) {
    case 'DEPORTES':
    case 'SPORTS':
      return 'Sports';
    case 'ESTUDIO':
    case 'STUDY':
      return 'Study';
    case 'CULTURA':
    case 'CULTURE':
      return 'Culture';
    case 'ENTRETENIMIENTO':
    case 'ENTERTAINMENT':
      return 'Entertainment';
    default:
      return backendValue ?? '';
  }
}

String _formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1)} km';
}

String _formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}
const localActivityIdPrefix = 'local-';

class Activity {
  bool get isPendingSync => id?.startsWith(localActivityIdPrefix) ?? false;
  const Activity({
    required this.category,
    required this.name,
    required this.distance,
    required this.duration,
    required this.price,
    required this.people,
    required this.imageUrl,
    this.fitsWindow = true,
    this.id,
    this.locationName,
    this.score,
    this.participants = 0,
    this.capacity,
    this.aboutLocation,
  });

  final String category;
  final String name;
  final String distance;
  final String duration;
  final String price;
  final String people;
  final String imageUrl;
  final bool fitsWindow;
  final String? id;
  final String? locationName;
  final double? score;
  final int participants;
  final int? capacity;
  final String? aboutLocation;

  String get spotsLabel => capacity == null
      ? '$participants inscritos'
      : '$participants/$capacity cupos';

  double? get spotsFraction => (capacity == null || capacity == 0)
      ? null
      : (participants / capacity!).clamp(0.0, 1.0);

  factory Activity.fromJson(
      Map<String, dynamic> json, {
        double? score,
        int? freeMinutes,
      }) {
    final start = DateTime.tryParse(json['startTime'] as String? ?? '');
    final end = DateTime.tryParse(json['endTime'] as String? ?? '');
    final minutes = (start != null && end != null)
        ? end.difference(start).inMinutes
        : null;
    final km = (json['distanceKm'] as num?)?.toDouble();
    final participants = (json['participants'] as num?)?.toInt() ?? 0;

    return Activity(
      id: json['id'] as String?,
      category: categoryLabel(json['category'] as String?),
      name: json['title'] as String? ?? '',
      locationName: json['locationName'] as String?,
      distance: km == null ? '' : _formatDistance(km),
      duration: minutes == null ? '' : _formatMinutes(minutes),
      price: json['price'] as String? ?? '',
      people: participants == 1 ? '1 registered' : '$participants registered participants',
      imageUrl: json['imageUrl'] as String? ?? '',
      participants: participants,
      capacity: (json['capacity'] as num?)?.toInt(),
      aboutLocation: json['aboutLocation'] as String?,
      fitsWindow:
      freeMinutes == null || minutes == null || minutes <= freeMinutes,
      score: score,
    );
  }
}

class FriendStatus {
  const FriendStatus({
    required this.initials,
    required this.name,
    required this.status,
    this.statusInMinutes = false,
  });

  final String initials;
  final String name;
  final String status;
  final bool statusInMinutes;
}
