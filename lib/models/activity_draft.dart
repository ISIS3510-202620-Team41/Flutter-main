import 'activity.dart';
import 'activity_record.dart';

class CategoryOption {
  const CategoryOption(this.label, this.backendValue, this.emoji);

  final String label;
  final String backendValue;
  final String emoji;
}

const categoryOptions = [
  CategoryOption('Deportes', 'DEPORTES', '⚽'),
  CategoryOption('Estudio', 'ESTUDIO', '📚'),
  CategoryOption('Cultura', 'CULTURA', '🎭'),
  CategoryOption('Entretenimiento', 'ENTRETENIMIENTO', '🎮'),
];

class PlaceOption {
  const PlaceOption({
    required this.name,
    required this.distance,
    required this.durationMinutes,
    required this.price,
    required this.latitude,
    required this.longitude,
    required this.capacity,
    required this.description,
    this.imageUrl = '',
  });

  final String name;
  final String distance;
  final int durationMinutes;
  final String price;
  final double latitude;
  final double longitude;
  final int capacity;
  final String description;
  final String imageUrl;

  String get durationLabel => durationMinutes % 60 == 0
      ? '${durationMinutes ~/ 60} h'
      : '$durationMinutes min';
}

// Lugares de prueba; más adelante provendrán del backend.
const availablePlaces = [
  PlaceOption(
    name: 'Bistro',
    distance: '500 m',
    durationMinutes: 120,
    price: '\$30K',
    latitude: 4.6012,
    longitude: -74.0655,
    capacity: 10,
    description: 'Restaurante cerca del campus',
  ),
  PlaceOption(
    name: 'Pizza Hut',
    distance: '0.7 km',
    durationMinutes: 90,
    price: '\$20K',
    latitude: 4.6050,
    longitude: -74.0680,
    capacity: 8,
    description: 'Pizzeria, ideal para grupos',
  ),
];

//Lo necesario para crear una actividad. Se puede almacenar sin conexión.
class ActivityDraft {
  const ActivityDraft({
    required this.clientId,
    required this.title,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.friends,
    this.price,
    this.capacity,
    this.aboutLocation,
    this.imageUrl,
  });

  final String clientId;
  final String title;
  final String category; // backend value, e.g. DEPORTES
  final DateTime startTime;
  final DateTime endTime;
  final String locationName;
  final double latitude;
  final double longitude;
  final List<String> friends;
  final String? price;
  final int? capacity;
  final String? aboutLocation;
  final String? imageUrl;

  /// POST /activities.
  Map<String, dynamic> toRequestJson() => {
    'title': title,
    'category': category,
    'startTime': startTime.toUtc().toIso8601String(),
    'endTime': endTime.toUtc().toIso8601String(),
    'locationName': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'price': price,
    'capacity': capacity,
    'aboutLocation': aboutLocation,
    if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
  };

  Map<String, dynamic> toStorageJson() => {
    ...toRequestJson(),
    'clientId': clientId,
    'friends': friends,
  };

  factory ActivityDraft.fromStorageJson(Map<String, dynamic> json) {
    return ActivityDraft(
      clientId: json['clientId'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      locationName: json['locationName'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      friends: List<String>.from(json['friends'] as List),
      price: json['price'] as String?,
      capacity: (json['capacity'] as num?)?.toInt(),
      aboutLocation: json['aboutLocation'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  //Versión local que se muestra en la pantalla de confirmación cuando no hay conexión
  Activity toActivity() {
    final minutes = endTime.difference(startTime).inMinutes;
    return Activity(
      category: categoryLabel(category),
      name: title,
      locationName: locationName,
      distance: '',
      duration: minutes % 60 == 0 ? '${minutes ~/ 60} h' : '$minutes min',
      price: price ?? '',
      people: '1 persona inscrita',
      imageUrl: imageUrl ?? '',
      participants: 1,
      capacity: capacity,
      aboutLocation: aboutLocation,
    );
  }
  //Fila guardada en SQLite mientras la actividad espera a ser sincronizada
  ActivityRecord toRecord(String id) => ActivityRecord(
    id: id,
    title: title,
    category: category,
    startTime: startTime.toUtc().toIso8601String(),
    endTime: endTime.toUtc().toIso8601String(),
    locationName: locationName,
    latitude: latitude,
    longitude: longitude,
    participants: 1,
    capacity: capacity,
    price: price,
    aboutLocation: aboutLocation,
    imageUrl: imageUrl,
    cachedAt: DateTime.now().toUtc(),
  );
}