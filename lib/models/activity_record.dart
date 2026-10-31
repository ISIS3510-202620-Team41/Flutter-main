import 'activity.dart';

class ActivityRecord {
  const ActivityRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.participants,
    required this.cachedAt,
    this.description,
    this.distanceKm,
    this.capacity,
    this.price,
    this.aboutLocation,
    this.imageUrl,
    this.localImagePath,
  });

  final String id;
  final String title;
  final String? description;
  final String category;

  final String startTime;
  final String endTime;

  final String locationName;
  final double latitude;
  final double longitude;

  final double? distanceKm;
  final int participants;

  final int? capacity;
  final String? price;
  final String? aboutLocation;
  final String? imageUrl;
  final String? localImagePath;

  // Metadata local no suplida por el Backend
  final DateTime cachedAt;

  // Crea un registro de lo que le llega del back
  factory ActivityRecord.fromJson(Map<String, dynamic> json, { DateTime? cachedAt,}) {
    return ActivityRecord(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      description: json['description'] as String?,
      category: _requiredString(json, 'category'),
      startTime: _requiredString(json, 'startTime'),
      endTime: _requiredString(json, 'endTime'),
      locationName: _requiredString(json, 'locationName'),
      latitude: _requiredDouble(json, 'latitude'),
      longitude: _requiredDouble(json, 'longitude'),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      participants:
          (json['participants'] as num?)?.toInt() ?? 0,
      capacity: (json['capacity'] as num?)?.toInt(),
      price: json['price'] as String?,
      aboutLocation: json['aboutLocation'] as String?,
      imageUrl: json['imageUrl'] as String?,
      cachedAt: (cachedAt ?? DateTime.now()).toUtc(),
    );
  }

  // Crea un registro de una fila del SQLite
  factory ActivityRecord.fromMap(Map<String, Object?> map,) {
    return ActivityRecord(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      category: map['category'] as String,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      locationName: map['location_name'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      distanceKm: (map['distance_km'] as num?)?.toDouble(),
      participants: (map['participants'] as num).toInt(),
      capacity: (map['capacity'] as num?)?.toInt(),
      price: map['price'] as String?,
      aboutLocation: map['about_location'] as String?,
      imageUrl: map['image_url'] as String?,
      cachedAt: DateTime.parse(map['cached_at'] as String),
      localImagePath: map['local_image_path'] as String?,
    );
  }
  // Convierte un record a columnas usadas en el SQLite
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'start_time': startTime,
      'end_time': endTime,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'distance_km': distanceKm,
      'participants': participants,
      'capacity': capacity,
      'price': price,
      'about_location': aboutLocation,
      'image_url': imageUrl,
      'cached_at': cachedAt.toUtc().toIso8601String(),
      'local_image_path': localImagePath,
    };
  }

  // Pasa el modelo a un modelo aceptado por la UI
  Activity toActivity({double? score, int? freeMinutes, double? calculatedDistanceKm, bool recalculateDistance = false, }) {
    return Activity.fromJson(
      {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'startTime': startTime,
        'endTime': endTime,
        'locationName': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'distanceKm': recalculateDistance
            ? calculatedDistanceKm
            : distanceKm,
        'participants': participants,
        'capacity': capacity,
        'price': price,
        'aboutLocation': aboutLocation,
        'imageUrl': imageUrl,
        'localImagePath': localImagePath,
      },
      score: score,
      freeMinutes: freeMinutes,
    );
  }

  ActivityRecord copyWith({
    String? localImagePath,
  }) {
    return ActivityRecord(
      id: id,
      title: title,
      description: description,
      category: category,
      startTime: startTime,
      endTime: endTime,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      distanceKm: distanceKm,
      participants: participants,
      capacity: capacity,
      price: price,
      aboutLocation: aboutLocation,
      imageUrl: imageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      cachedAt: cachedAt,
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key,) {
    final value = json[key];

    if (value is String && value.isNotEmpty) {
      return value;
    }

    throw FormatException(
      'Missing or invalid required activity field: $key',
    );
  }

  static double _requiredDouble(Map<String, dynamic> json, String key,) {
    final value = json[key];

    if (value is num) {
      return value.toDouble();
    }

    throw FormatException(
      'Missing or invalid required activity field: $key',
    );
  }
}
