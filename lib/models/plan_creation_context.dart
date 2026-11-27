class PlanCreationContext {
  const PlanCreationContext({
    required this.preferences,
    required this.freeTimeMinutes,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.availableFriendsCount,
    required this.selectedAvailableFriendsCount,
  });

  final List<String> preferences;
  final int freeTimeMinutes;
  final String locationName;
  final double latitude;
  final double longitude;
  final int availableFriendsCount;
  final int selectedAvailableFriendsCount;

  Map<String, dynamic> toMap() => {
    'preferences': preferences,
    'freeTimeMinutes': freeTimeMinutes,
    'locationName': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'availableFriendsCount': availableFriendsCount,
    'selectedAvailableFriendsCount': selectedAvailableFriendsCount,
  };

  factory PlanCreationContext.fromMap(Map<String, dynamic> map) {
    return PlanCreationContext(
      preferences: List<String>.from(map['preferences'] as List),
      freeTimeMinutes: map['freeTimeMinutes'] as int,
      locationName: map['locationName'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      availableFriendsCount: map['availableFriendsCount'] as int,
      selectedAvailableFriendsCount:
          map['selectedAvailableFriendsCount'] as int,
    );
  }
}
