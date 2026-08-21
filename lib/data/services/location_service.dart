import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class MunibLocation {
  final double latitude;
  final double longitude;
  final String city;

  const MunibLocation({
    required this.latitude,
    required this.longitude,
    required this.city,
  });
}

class LocationService {
  Future<MunibLocation> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('location_service_disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('location_permission_denied');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('location_permission_denied_forever');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );

    String city = '${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}';
    try {
      final places = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (places.isNotEmpty) {
        final place = places.first;
        final locality = (place.locality?.trim().isNotEmpty ?? false)
            ? place.locality!.trim()
            : (place.administrativeArea?.trim() ?? '');
        final country = place.country?.trim() ?? '';
        city = [locality, country].where((e) => e.isNotEmpty).join(', ');
      }
    } catch (_) {
      // Coordinates are still valid even if reverse geocoding is unavailable.
    }

    return MunibLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      city: city,
    );
  }

  Future<String> getCurrentCity() async => (await getCurrentLocation()).city;
}
