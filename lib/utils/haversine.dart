import 'dart:math' as math;

class Haversine {
  static const double earthRadiusKm = 6371.0;

  static double? calculateDistanceKm({
    required double? latitude1,
    required double? longitude1,
    required double? latitude2,
    required double? longitude2,
  }) {
    if (latitude1 == null ||
        longitude1 == null ||
        latitude2 == null ||
        longitude2 == null) {
      return null;
    }

    if (!latitude1.isFinite ||
        !longitude1.isFinite ||
        !latitude2.isFinite ||
        !longitude2.isFinite ||
        latitude1 < -90 ||
        latitude1 > 90 ||
        latitude2 < -90 ||
        latitude2 > 90 ||
        longitude1 < -180 ||
        longitude1 > 180 ||
        longitude2 < -180 ||
        longitude2 > 180) {
      return null;
    }

    final lat1 = latitude1 * math.pi / 180;
    final lat2 = latitude2 * math.pi / 180;

    final deltaLat =
        (latitude2 - latitude1) * math.pi / 180;

    final deltaLon =
        (longitude2 - longitude1) * math.pi / 180;

    final sinLat = math.sin(deltaLat / 2);
    final sinLon = math.sin(deltaLon / 2);

    final a = sinLat * sinLat +
        math.cos(lat1) *
            math.cos(lat2) *
            sinLon *
            sinLon;

    final safeA = a.clamp(0.0, 1.0).toDouble();

    final c = 2 * math.atan2(
      math.sqrt(safeA),
      math.sqrt(1 - safeA),
    );

    return earthRadiusKm * c;
  }
}
