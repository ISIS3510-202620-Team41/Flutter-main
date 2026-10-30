import 'package:flutter_test/flutter_test.dart';
import 'package:llamalla/utils/haversine.dart';

void main() {
  group('Haversine.calculateDistanceKm', () {
    test('returns zero for identical coordinates', () {
      final result = Haversine.calculateDistanceKm(
        latitude1: 4.6097,
        longitude1: -74.0817,
        latitude2: 4.6097,
        longitude2: -74.0817,
      );

      expect(result, closeTo(0, 0.000001));
    });

    test('calculates distance between different coordinates', () {
      final result = Haversine.calculateDistanceKm(
        latitude1: 0,
        longitude1: 0,
        latitude2: 0,
        longitude2: 1,
      );

      expect(result, closeTo(111.19, 0.1));
    });

    test('returns null when a coordinate is missing', () {
      final result = Haversine.calculateDistanceKm(
        latitude1: null,
        longitude1: 0,
        latitude2: 0,
        longitude2: 1,
      );

      expect(result, isNull);
    });

    test('returns null for invalid coordinates', () {
      final result = Haversine.calculateDistanceKm(
        latitude1: 95,
        longitude1: 0,
        latitude2: 0,
        longitude2: 1,
      );

      expect(result, isNull);
    });
  });
}