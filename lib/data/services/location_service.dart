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

  Future<bool> hasGrantedPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<MunibLocation> getCurrentLocation({
    bool requestPermission = false,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('location_service_disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
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

    String city =
        '${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}';
    String countryCode = '';
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
    } catch (_) {}

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
