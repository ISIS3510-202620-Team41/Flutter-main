enum ActivityComparisonCriterion {
  duration('duration', 'Duración'),
  category('category', 'Categoría'),
  price('price', 'Precio'),
  location('location', 'Ubicación'),
  distance('distance', 'Distancia'),
  capacity('capacity', 'Capacidad');

  const ActivityComparisonCriterion(this.key, this.label);

  final String key;
  final String label;

  static ActivityComparisonCriterion? fromKey(String key) {
    for (final criterion in values) {
      if (criterion.key == key) return criterion;
    }
    return null;
  }
}

class ActivityComparisonCriteria {
  const ActivityComparisonCriteria({
    this.weights = initialWeights,
    this.preferredLocation,
  });

  static const Map<ActivityComparisonCriterion, int> initialWeights = {
    ActivityComparisonCriterion.duration: 25,
    ActivityComparisonCriterion.category: 20,
    ActivityComparisonCriterion.price: 20,
    ActivityComparisonCriterion.location: 15,
    ActivityComparisonCriterion.distance: 10,
    ActivityComparisonCriterion.capacity: 10,
  };

  static const maximumWeight = 60;

  final Map<ActivityComparisonCriterion, int> weights;
  final String? preferredLocation;

  int get totalWeight => ActivityComparisonCriterion.values.fold<int>(
    0,
    (total, criterion) => total + (weights[criterion] ?? 0),
  );

  ActivityComparisonCriteria withWeight(
    ActivityComparisonCriterion changedCriterion,
    int requestedValue,
  ) {
    final value = requestedValue.clamp(0, maximumWeight);
    final otherCriteria = ActivityComparisonCriterion.values
        .where((criterion) => criterion != changedCriterion)
        .toList(growable: false);
    var remaining = 100 - value;
    final nextWeights = <ActivityComparisonCriterion, int>{
      changedCriterion: value,
    };
    var active = List<ActivityComparisonCriterion>.of(otherCriteria);

    while (active.isNotEmpty && remaining > 0) {
      final sourceTotal = active.fold<int>(
        0,
        (total, criterion) => total + (weights[criterion] ?? 0),
      );
      final shares = <ActivityComparisonCriterion, double>{};

      for (final criterion in active) {
        shares[criterion] = sourceTotal == 0
            ? remaining / active.length
            : remaining * (weights[criterion] ?? 0) / sourceTotal;
      }

      final capped = active
          .where((criterion) => shares[criterion]! > maximumWeight)
          .toList(growable: false);
      if (capped.isNotEmpty) {
        for (final criterion in capped) {
          nextWeights[criterion] = maximumWeight;
          remaining -= maximumWeight;
          active.remove(criterion);
        }
        continue;
      }

      for (final criterion in active) {
        nextWeights[criterion] = shares[criterion]!.floor();
      }

      var unassigned =
          remaining -
          active.fold<int>(
            0,
            (total, criterion) => total + nextWeights[criterion]!,
          );
      final byLargestRemainder = List<ActivityComparisonCriterion>.of(active)
        ..sort((left, right) {
          final remainderOrder = (shares[right]! - shares[right]!.floor())
              .compareTo(shares[left]! - shares[left]!.floor());
          if (remainderOrder != 0) return remainderOrder;
          return left.index.compareTo(right.index);
        });

      for (final criterion in byLargestRemainder) {
        if (unassigned == 0) break;
        if (nextWeights[criterion]! < maximumWeight) {
          nextWeights[criterion] = nextWeights[criterion]! + 1;
          unassigned--;
        }
      }
      remaining = 0;
    }

    return ActivityComparisonCriteria(
      weights: Map.unmodifiable(nextWeights),
      preferredLocation: preferredLocation,
    );
  }

  ActivityComparisonCriteria withPreferredLocation(String? location) =>
      ActivityComparisonCriteria(weights: weights, preferredLocation: location);

  Map<String, Object?> toMap() => {
    'weights': {
      for (final criterion in ActivityComparisonCriterion.values)
        criterion.key: weights[criterion],
    },
    'preferredLocation': preferredLocation,
  };

  factory ActivityComparisonCriteria.fromMap(Map<String, dynamic> map) {
    final rawWeights = map['weights'];
    if (rawWeights is! Map) {
      throw const FormatException('Comparison weights are missing.');
    }

    final weights = <ActivityComparisonCriterion, int>{};
    for (final criterion in ActivityComparisonCriterion.values) {
      final rawValue = rawWeights[criterion.key];
      if (rawValue is! num || rawValue != rawValue.round()) {
        throw FormatException('Invalid weight for ${criterion.key}.');
      }
      final value = rawValue.toInt();
      if (value < 0 || value > maximumWeight) {
        throw FormatException('Invalid weight for ${criterion.key}.');
      }
      weights[criterion] = value;
    }

    final criteria = ActivityComparisonCriteria(
      weights: Map.unmodifiable(weights),
      preferredLocation: map['preferredLocation'] as String?,
    );
    if (criteria.totalWeight != 100) {
      throw const FormatException('Comparison weights must total 100.');
    }
    return criteria;
  }
}
