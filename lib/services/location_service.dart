import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LocationSource {
  current,
  lastKnown,
  cached,
}

enum LocationIssue {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class UserLocation {
  const UserLocation(
    this.lat,
    this.lon, {
    this.source = LocationSource.current,
    this.timestamp,
  });

  final double lat;
  final double lon;
  final LocationSource source;
  final DateTime? timestamp;
}

class LocationResult {
  const LocationResult({
    this.location,
    this.issue,
  });

  final UserLocation? location;
  final LocationIssue? issue;

  bool get hasLocation => location != null;
}

class LocationService {
  LocationService({
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function()
      _preferencesProvider;

  static const _latitudeKey = 'last_location_lat';
  static const _longitudeKey = 'last_location_lon';
  static const _timestampKey = 'last_location_timestamp';

  static const _maxCacheAge = Duration(hours: 24);

  Future<LocationResult> current() async {
    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return _cachedOrIssue(
          LocationIssue.serviceDisabled,
        );
      }

      // Solicitar permisos
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return _cachedOrIssue(
          LocationIssue.permissionDeniedForever,
        );
      }

      if (permission == LocationPermission.denied) {
        return _cachedOrIssue(
          LocationIssue.permissionDenied,
        );
      }

      // Obtenemos la posición actual con un tiempo límite de 8 segundos.
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 8),
          ),
        );

        final location = UserLocation(
          position.latitude,
          position.longitude,
          source: LocationSource.current,
          timestamp: position.timestamp,
        );

        await _saveLocation(location);

        return LocationResult(location: location);
      } catch (_) {
        // Si falla GPS, intentamos recuperar la última posición.
      }

      // Intentar recuperar última posición de Geolocator.
      final lastKnown =
          await Geolocator.getLastKnownPosition();

      if (lastKnown != null &&
          _isFresh(lastKnown.timestamp)) {
        final location = UserLocation(
          lastKnown.latitude,
          lastKnown.longitude,
          source: LocationSource.lastKnown,
          timestamp: lastKnown.timestamp,
        );

        await _saveLocation(location);

        return LocationResult(location: location);
      }
    } catch (_) {
      // Continuamos intentando recuperar la caché local.
    }

    return _cachedOrIssue(LocationIssue.unavailable);
  }

  Future<LocationResult> _cachedOrIssue(
    LocationIssue issue,
  ) async {
    final cached = await _readCachedLocation();

    return LocationResult(
      location: cached,
      issue: issue,
    );
  }

  Future<void> _saveLocation(
    UserLocation location,
  ) async {
    final preferences = await _preferencesProvider();

    await preferences.setDouble(
      _latitudeKey,
      location.lat,
    );

    await preferences.setDouble(
      _longitudeKey,
      location.lon,
    );

    await preferences.setInt(
      _timestampKey,
      location.timestamp!
          .millisecondsSinceEpoch,
    );
  }

  Future<UserLocation?> _readCachedLocation() async {
    final preferences = await _preferencesProvider();

    final lat = preferences.getDouble(_latitudeKey);
    final lon = preferences.getDouble(_longitudeKey);
    final timestampMs =
        preferences.getInt(_timestampKey);

    if (lat == null || lon == null || timestampMs == null) {
      return null;
    }

    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      timestampMs,
    );

    if (!_isFresh(timestamp)) {
      return null;
    }

    if (!lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      return null;
    }

    return UserLocation(
      lat,
      lon,
      source: LocationSource.cached,
      timestamp: timestamp,
    );
  }

  bool _isFresh(DateTime timestamp) {
    final age = DateTime.now().difference(timestamp);

    return !age.isNegative && age <= _maxCacheAge;
  }

  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }
}