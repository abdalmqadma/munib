import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class MunibLocation {
  final double latitude;
  final double longitude;
  final String city;
  final String countryCode;

  const MunibLocation({
    required this.latitude,
    required this.longitude,
    required this.city,
    this.countryCode = '',
  });
}

enum MunibLocationAccess {
  granted,
  serviceDisabled,
  denied,
  deniedForever,
}

class LocationService {
  Future<MunibLocationAccess> accessState() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return MunibLocationAccess.serviceDisabled;
    }
    return _mapPermission(await Geolocator.checkPermission());
  }

  Future<MunibLocationAccess> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return MunibLocationAccess.serviceDisabled;
    }
    final current = await Geolocator.checkPermission();
    if (current == LocationPermission.always ||
        current == LocationPermission.whileInUse) {
      return MunibLocationAccess.granted;
    }
    if (current == LocationPermission.deniedForever) {
      return MunibLocationAccess.deniedForever;
    }
    return _mapPermission(await Geolocator.requestPermission());
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> hasGrantedPermission() async =>
      await accessState() == MunibLocationAccess.granted;

  Future<MunibLocation> getCurrentLocation({
    bool requestPermission = false,
  }) async {
    var access = await accessState();
    if (access == MunibLocationAccess.denied && requestPermission) {
      access = await requestAccess();
    }

    switch (access) {
      case MunibLocationAccess.serviceDisabled:
        throw Exception('location_service_disabled');
      case MunibLocationAccess.denied:
        throw Exception('location_permission_denied');
      case MunibLocationAccess.deniedForever:
        throw Exception('location_permission_denied_forever');
      case MunibLocationAccess.granted:
        break;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );

    var city =
        '${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}';
    var countryCode = '';
    try {
      final places =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (places.isNotEmpty) {
        final place = places.first;
        final locality = (place.locality?.trim().isNotEmpty ?? false)
            ? place.locality!.trim()
            : (place.administrativeArea?.trim() ?? '');
        final country = place.country?.trim() ?? '';
        countryCode = place.isoCountryCode?.trim().toUpperCase() ?? '';
        city = [locality, country].where((e) => e.isNotEmpty).join(', ');
      }
    } catch (_) {
      // Coordinates are still valid if reverse geocoding is temporarily unavailable.
    }

    return MunibLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      city: city,
      countryCode: countryCode,
    );
  }

  Future<String> getCurrentCity({bool requestPermission = false}) async =>
      (await getCurrentLocation(requestPermission: requestPermission)).city;

  MunibLocationAccess _mapPermission(LocationPermission permission) {
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return MunibLocationAccess.granted;
    }
    if (permission == LocationPermission.deniedForever) {
      return MunibLocationAccess.deniedForever;
    }
    return MunibLocationAccess.denied;
  }
}
