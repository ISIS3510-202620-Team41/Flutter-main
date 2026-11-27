import 'dart:math' as math;

import '../models/activity_comparison_criteria.dart';

@pragma('vm:entry-point')
List<Map<String, Object?>> compareActivitiesInWorker(
  Map<String, Object?> payload,
) {
  final rawRecords = payload['records'];
  final rawWeights = payload['weights'];
  if (rawRecords is! List || rawWeights is! Map) {
    throw const FormatException('Invalid comparison worker input.');
  }

  final weights = <ActivityComparisonCriterion, int>{};
  for (final criterion in ActivityComparisonCriterion.values) {
    final value = rawWeights[criterion.key];
    if (value is! num || value != value.round()) {
      throw FormatException('Invalid weight for ${criterion.key}.');
    }
    weights[criterion] = value.toInt();
  }

  final weightTotal = weights.values.fold<int>(
    0,
    (total, value) => total + value,
  );
  if (weightTotal != 100 ||
      weights.values.any(
        (weight) =>
            weight < 0 || weight > ActivityComparisonCriteria.maximumWeight,
      )) {
    throw const FormatException('Comparison weights must total 100.');
  }

  final records = rawRecords
      .map((record) => Map<String, Object?>.from(record as Map))
      .toList(growable: false);
  if (records.length < 2 || records.length > 10) {
    throw const FormatException(
      'A comparison requires between 2 and 10 activities.',
    );
  }
  final ids = records.map((record) => _requiredString(record, 'id')).toSet();
  if (ids.length != records.length) {
    throw const FormatException('Comparison activity IDs must be unique.');
  }

  final preferredCategories =
      (payload['preferredCategories'] as List? ?? const [])
          .whereType<String>()
          .map((category) => category.trim().toLowerCase())
          .where((category) => category.isNotEmpty)
          .toSet();
  final preferredLocation = _normalize(payload['preferredLocation'] as String?);
  final latitude = (payload['referenceLatitude'] as num?)?.toDouble();
  final longitude = (payload['referenceLongitude'] as num?)?.toDouble();

  final distances = <String, double?>{
    for (final record in records)
      _requiredString(record, 'id'): _distanceFromReference(
        record,
        latitude,
        longitude,
      ),
  };
  final durations = <String, double?>{
    for (final record in records)
      _requiredString(record, 'id'): _durationMinutes(record),
  };
  final prices = <String, double?>{
    for (final record in records)
      _requiredString(record, 'id'): _priceValue(record['price']),
  };
  final capacities = <String, double?>{
    for (final record in records)
      _requiredString(record, 'id'): _availableCapacity(record),
  };

  final normalized = <String, Map<ActivityComparisonCriterion, int?>>{};
  for (final record in records) {
    final id = _requiredString(record, 'id');
    normalized[id] = {
      ActivityComparisonCriterion.duration: _normalizeNumeric(
        durations.values,
        durations[id],
        lowerIsBetter: true,
      ),
      ActivityComparisonCriterion.category: _categoryScore(
        record['category'],
        preferredCategories,
      ),
      ActivityComparisonCriterion.price: _normalizeNumeric(
        prices.values,
        prices[id],
        lowerIsBetter: true,
      ),
      ActivityComparisonCriterion.location: _locationScore(
        record['location_name'],
        preferredLocation,
      ),
      ActivityComparisonCriterion.distance: _normalizeNumeric(
        distances.values,
        distances[id],
        lowerIsBetter: true,
      ),
      ActivityComparisonCriterion.capacity: _normalizeNumeric(
        capacities.values,
        capacities[id],
        lowerIsBetter: false,
      ),
    };
  }

  final results = <Map<String, Object?>>[];
  for (final record in records) {
    final id = _requiredString(record, 'id');
    final contributions = <String, Object?>{};
    var totalScore = 0.0;

    for (final criterion in ActivityComparisonCriterion.values) {
      final score = normalized[id]![criterion];
      final weight = weights[criterion]!;
      final contribution = (score ?? 0) * weight / 100;
      totalScore += contribution;
      contributions[criterion.key] = {
        'weight': weight,
        'normalizedScore': score,
        'score': contribution,
        'displayValue': _displayValue(
          criterion,
          record,
          durations[id],
          prices[id],
          distances[id],
          capacities[id],
        ),
        'explanation': _explanation(
          criterion,
          score,
          record,
          preferredCategories,
          preferredLocation,
          latitude != null && longitude != null,
        ),
      };
    }

    results.add({
      'activityId': id,
      'score': totalScore,
      'contributions': contributions,
    });
  }

  results.sort((left, right) {
    final scoreOrder = (right['score'] as double).compareTo(
      left['score'] as double,
    );
    if (scoreOrder != 0) return scoreOrder;
    return (left['activityId'] as String).compareTo(
      right['activityId'] as String,
    );
  });
  return results;
}

String _displayValue(
  ActivityComparisonCriterion criterion,
  Map<String, Object?> record,
  double? durationMinutes,
  double? price,
  double? distanceKm,
  double? availableCapacity,
) {
  switch (criterion) {
    case ActivityComparisonCriterion.duration:
      return durationMinutes == null
          ? 'No disponible'
          : '${durationMinutes.round()} min';
    case ActivityComparisonCriterion.category:
      return _nonEmptyString(record['category']) ?? 'No informada';
    case ActivityComparisonCriterion.price:
      return price == null
          ? 'No informado'
          : (_nonEmptyString(record['price']) ?? 'Gratis');
    case ActivityComparisonCriterion.location:
      return _nonEmptyString(record['location_name']) ?? 'No informada';
    case ActivityComparisonCriterion.distance:
      if (distanceKm == null) return 'No disponible';
      return distanceKm < 1
          ? '${(distanceKm * 1000).round()} m'
          : '${distanceKm.toStringAsFixed(1)} km';
    case ActivityComparisonCriterion.capacity:
      return availableCapacity == null
          ? 'No informada'
          : '${availableCapacity.round()} cupos disponibles';
  }
}

String? _nonEmptyString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

int? _normalizeNumeric(
  Iterable<double?> values,
  double? value, {
  required bool lowerIsBetter,
}) {
  if (value == null || !value.isFinite) return null;
  final available = values.whereType<double>().toList(growable: false);
  if (available.isEmpty) return null;
  final minimum = available.reduce(math.min);
  final maximum = available.reduce(math.max);
  if (minimum == maximum) return 100;

  final ratio = lowerIsBetter
      ? (maximum - value) / (maximum - minimum)
      : (value - minimum) / (maximum - minimum);
  return (ratio.clamp(0.0, 1.0) * 100).round();
}

int? _categoryScore(Object? rawCategory, Set<String> preferredCategories) {
  final category = _normalize(rawCategory as String?);
  if (category == null) return null;
  if (preferredCategories.isEmpty) return 50;
  return preferredCategories.contains(category) ? 100 : 0;
}

int? _locationScore(Object? rawLocation, String? preferredLocation) {
  final location = _normalize(rawLocation as String?);
  if (location == null || preferredLocation == null) return null;
  return location == preferredLocation ? 100 : 0;
}

double? _durationMinutes(Map<String, Object?> record) {
  final start = DateTime.tryParse(record['start_time'] as String? ?? '');
  final end = DateTime.tryParse(record['end_time'] as String? ?? '');
  if (start == null || end == null) return null;
  final minutes = end.difference(start).inMinutes;
  return minutes > 0 ? minutes.toDouble() : null;
}

double? _priceValue(Object? rawPrice) {
  if (rawPrice is! String || rawPrice.trim().isEmpty) return null;
  final value = rawPrice.trim().toLowerCase();
  if (value.contains('gratis') || value == 'free') return 0;

  final thousands = RegExp(r'(\d+(?:[.,]\d+)?)\s*k\b').firstMatch(value);
  if (thousands != null) {
    final amount = double.tryParse(thousands.group(1)!.replaceAll(',', '.'));
    return amount == null ? null : amount * 1000;
  }

  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : double.tryParse(digits);
}

double? _availableCapacity(Map<String, Object?> record) {
  final capacity = (record['capacity'] as num?)?.toDouble();
  final participants = (record['participants'] as num?)?.toDouble();
  if (capacity == null || participants == null || capacity <= 0) return null;
  return math.max(0, capacity - participants);
}

double? _distanceFromReference(
  Map<String, Object?> record,
  double? referenceLatitude,
  double? referenceLongitude,
) {
  if (referenceLatitude == null || referenceLongitude == null) return null;
  if (!referenceLatitude.isFinite ||
      !referenceLongitude.isFinite ||
      referenceLatitude < -90 ||
      referenceLatitude > 90 ||
      referenceLongitude < -180 ||
      referenceLongitude > 180) {
    return null;
  }
  final latitude = (record['latitude'] as num?)?.toDouble();
  final longitude = (record['longitude'] as num?)?.toDouble();
  if (latitude == null ||
      longitude == null ||
      !latitude.isFinite ||
      !longitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    return null;
  }

  const earthRadiusKm = 6371.0;
  final lat1 = referenceLatitude * math.pi / 180;
  final lat2 = latitude * math.pi / 180;
  final deltaLat = (latitude - referenceLatitude) * math.pi / 180;
  final deltaLon = (longitude - referenceLongitude) * math.pi / 180;
  final a =
      (math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
              math.cos(lat1) *
                  math.cos(lat2) *
                  math.sin(deltaLon / 2) *
                  math.sin(deltaLon / 2))
          .clamp(0.0, 1.0);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

String? _normalize(String? value) {
  final normalized = value?.trim().toLowerCase();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _requiredString(Map<String, Object?> record, String key) {
  final value = record[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Missing comparison field: $key.');
}

String _explanation(
  ActivityComparisonCriterion criterion,
  int? score,
  Map<String, Object?> record,
  Set<String> preferredCategories,
  String? preferredLocation,
  bool hasReferenceLocation,
) {
  if (score == null) {
    if (criterion == ActivityComparisonCriterion.location &&
        preferredLocation == null) {
      return 'Selecciona una ubicación preferida para puntuar este criterio.';
    }
    if (criterion == ActivityComparisonCriterion.category &&
        _normalize(record['category'] as String?) != null &&
        preferredCategories.isEmpty) {
      return 'Sin categorías favoritas; puntuación neutral.';
    }
    if (criterion == ActivityComparisonCriterion.distance &&
        !hasReferenceLocation) {
      return 'No hay una ubicación de referencia disponible.';
    }
    return 'Dato no disponible; no suma puntos.';
  }

  switch (criterion) {
    case ActivityComparisonCriterion.category:
      return preferredCategories.isEmpty
          ? 'Puntuación neutral: no hay categorías favoritas.'
          : score == 100
          ? 'Coincide con una categoría favorita.'
          : 'No coincide con tus categorías favoritas.';
    case ActivityComparisonCriterion.location:
      return score == 100
          ? 'Coincide con la ubicación que elegiste.'
          : 'Está en una ubicación diferente a la que elegiste.';
    case ActivityComparisonCriterion.duration:
      return 'Duración: ${record['start_time']} – ${record['end_time']}.';
    case ActivityComparisonCriterion.price:
      return 'Precio informado: ${record['price']}.';
    case ActivityComparisonCriterion.distance:
      return 'Distancia calculada desde tu ubicación de referencia.';
    case ActivityComparisonCriterion.capacity:
      final available = _availableCapacity(record);
      return available == null
          ? 'Capacidad no disponible.'
          : '${available.round()} cupos disponibles.';
  }
}
