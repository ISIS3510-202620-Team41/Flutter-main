import 'package:flutter/foundation.dart';

import '../models/activity_record.dart';
import 'haversine.dart';

class DistanceCalculator {
  static Future<List<ActivityRecord>> process({
    required List<ActivityRecord> records,
    required double userLat,
    required double userLon,
    double radiusKm = 50,
    bool filterByRadius = true,
    bool sortByDistance = true,
  }) async {
    if (records.isEmpty) {
      return const [];
    }

    // Convertimos los modelos a datos transferibles
    final payload = <String, Object?>{
      'records': records.map((record) => record.toMap()).toList(),
      'userLat': userLat,
      'userLon': userLon,
      'radiusKm': radiusKm,
      'filterByRadius': filterByRadius,
      'sortByDistance': sortByDistance,
    };

    // Ejecutamos en isolate el proceso
    final processedRecords =
        await compute<Map<String, Object?>,
            List<Map<String, Object?>>>(
      processActivitiesInIsolate,
      payload,
      debugLabel: 'activity-distance-processing',
    );

    // Reconstruimos los modelos
    return processedRecords
        .map((record) => ActivityRecord.fromMap(record))
        .toList(growable: false);
  }
}

@pragma('vm:entry-point')
List<Map<String, Object?>> processActivitiesInIsolate(
  Map<String, Object?> payload,
) {
  final records = payload['records'] as List;

  final userLat = (payload['userLat'] as num).toDouble();
  final userLon = (payload['userLon'] as num).toDouble();

  final radiusKm = (payload['radiusKm'] as num).toDouble();

  final filterByRadius =
      payload['filterByRadius'] as bool;

  final sortByDistance =
      payload['sortByDistance'] as bool;

  final results = <Map<String, Object?>>[];

  for (final rawRecord in records) {
    final record = Map<String, Object?>.from(
      rawRecord as Map,
    );

    final distanceKm = Haversine.calculateDistanceKm(
      latitude1: userLat,
      longitude1: userLon,
      latitude2: (record['latitude'] as num?)?.toDouble(),
      longitude2: (record['longitude'] as num?)?.toDouble(),
    );

    // No conservamos actividades con coordenadas inválidas.
    if (distanceKm == null) {
      continue;
    }

    // Filtramos las actividades fuera del radio.
    if (filterByRadius && distanceKm > radiusKm) {
      continue;
    }

    // Guardamos la distancia calculada en el registro.
    record['distance_km'] = distanceKm;

    results.add(record);
  }

  // Ordenamos de la actividad más cercana a la más lejana.
  if (sortByDistance) {
    results.sort((a, b) {
      final distanceA =
          (a['distance_km'] as num).toDouble();

      final distanceB =
          (b['distance_km'] as num).toDouble();

      return distanceA.compareTo(distanceB);
    });
  }

  return results;
}
