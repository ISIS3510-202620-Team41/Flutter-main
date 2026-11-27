import 'activity_comparison_criteria.dart';

class ActivityComparisonContribution {
  const ActivityComparisonContribution({
    required this.weight,
    required this.normalizedScore,
    required this.score,
    required this.explanation,
    this.displayValue,
  });

  final int weight;
  final int? normalizedScore;
  final double score;
  final String explanation;
  final String? displayValue;

  Map<String, Object?> toMap() => {
    'weight': weight,
    'normalizedScore': normalizedScore,
    'score': score,
    'explanation': explanation,
    'displayValue': displayValue,
  };

  factory ActivityComparisonContribution.fromMap(Map<String, dynamic> map) =>
      ActivityComparisonContribution(
        weight: (map['weight'] as num).toInt(),
        normalizedScore: (map['normalizedScore'] as num?)?.toInt(),
        score: (map['score'] as num).toDouble(),
        explanation: map['explanation'] as String,
        displayValue: map['displayValue'] as String?,
      );
}

class ActivityComparisonResult {
  const ActivityComparisonResult({
    required this.activityId,
    required this.score,
    required this.contributions,
  });

  final String activityId;
  final double score;
  final Map<ActivityComparisonCriterion, ActivityComparisonContribution>
  contributions;

  Map<String, Object?> toMap() => {
    'activityId': activityId,
    'score': score,
    'contributions': {
      for (final entry in contributions.entries)
        entry.key.key: entry.value.toMap(),
    },
  };

  factory ActivityComparisonResult.fromMap(Map<String, dynamic> map) {
    final rawContributions = map['contributions'];
    if (rawContributions is! Map) {
      throw const FormatException('Comparison contributions are missing.');
    }

    final contributions =
        <ActivityComparisonCriterion, ActivityComparisonContribution>{};
    for (final criterion in ActivityComparisonCriterion.values) {
      final rawValue = rawContributions[criterion.key];
      if (rawValue is! Map) {
        throw FormatException('Invalid contribution for ${criterion.key}.');
      }
      contributions[criterion] = ActivityComparisonContribution.fromMap(
        Map<String, dynamic>.from(rawValue),
      );
    }

    return ActivityComparisonResult(
      activityId: map['activityId'] as String,
      score: (map['score'] as num).toDouble(),
      contributions: Map.unmodifiable(contributions),
    );
  }
}
