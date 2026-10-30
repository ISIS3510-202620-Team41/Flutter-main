class UserPreference {
  //Funcionamiento muy similar a lo que pasa en activity_record
  const UserPreference({
    required this.id,
    required this.userId,
    required this.category,
    required this.score,
    required this.cachedAt,
  });

  final String id;
  final String userId;
  final String category;
  final double score;
  final DateTime cachedAt;

  factory UserPreference.fromJson(Map<String, dynamic> json) {
    return UserPreference(
      id: json['id'] as String,
      userId: json['userId'] as String,
      category: json['category'] as String,
      score: (json['score'] as num).toDouble(),
      cachedAt: DateTime.now().toUtc(),
    );
  }

  factory UserPreference.fromMap(Map<String, Object?> map) {
    return UserPreference(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      category: map['category'] as String,
      score: (map['score'] as num).toDouble(),
      cachedAt: DateTime.parse(map['cached_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'category': category,
      'score': score,
      'cached_at': cachedAt.toUtc().toIso8601String(),
    };
  }
}
