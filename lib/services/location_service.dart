import 'package:geolocator/geolocator.dart';

class UserLocation {
  const UserLocation(this.lat, this.lon, {this.isFallback = false});

  final double lat;
  final double lon;
  final bool isFallback;
}

class LocationService {
  static const _fallback = UserLocation(4.6097, -74.0817, isFallback: true);

  Future<UserLocation> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _fallback;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _fallback;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return UserLocation(position.latitude, position.longitude);
    } catch (_) {
      return _fallback;
    }
  }
}