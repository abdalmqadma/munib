import 'package:flutter/foundation.dart';
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
  static const _tag = 'MUNIB_IMSAKIA';

  Future<MunibLocationAccess> accessState() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('[$_tag][LOCATION] serviceEnabled=$serviceEnabled');
    if (!serviceEnabled) {
      return MunibLocationAccess.serviceDisabled;
    }
    final permission = await Geolocator.checkPermission();
    final mapped = _mapPermission(permission);
    debugPrint('[$_tag][LOCATION] permission=$permission mapped=$mapped');
    return mapped;
  }

  Future<MunibLocationAccess> requestAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('[$_tag][LOCATION] requestAccess serviceEnabled=$serviceEnabled');
    if (!serviceEnabled) {
      return MunibLocationAccess.serviceDisabled;
    }
    final current = await Geolocator.checkPermission();
    debugPrint('[$_tag][LOCATION] permissionBeforeRequest=$current');
    if (current == LocationPermission.always ||
        current == LocationPermission.whileInUse) {
      return MunibLocationAccess.granted;
    }
    if (current == LocationPermission.deniedForever) {
      return MunibLocationAccess.deniedForever;
    }
    final requested = await Geolocator.requestPermission();
    debugPrint('[$_tag][LOCATION] permissionAfterRequest=$requested');
    return _mapPermission(requested);
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  Future<bool> hasGrantedPermission() async =>
      await accessState() == MunibLocationAccess.granted;

  Future<MunibLocation> getCurrentLocation({
    bool requestPermission = false,
  }) async {
    debugPrint('[$_tag][LOCATION] getCurrentLocation requestPermission=$requestPermission');
    try {
      var access = await accessState();
      if (access == MunibLocationAccess.denied && requestPermission) {
        access = await requestAccess();
      }
      debugPrint('[$_tag][LOCATION] effectiveAccess=$access');

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
      debugPrint('[$_tag][LOCATION] position lat=${position.latitude} lon=${position.longitude} accuracy=${position.accuracy}');

      var city =
          '${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}';
      var countryCode = '';
      try {
        final places =
            await placemarkFromCoordinates(position.latitude, position.longitude);
        debugPrint('[$_tag][LOCATION] reverseGeocode results=${places.length}');
        if (places.isNotEmpty) {
          final place = places.first;
          final locality = (place.locality?.trim().isNotEmpty ?? false)
              ? place.locality!.trim()
              : (place.administrativeArea?.trim() ?? '');
          final country = place.country?.trim() ?? '';
          countryCode = place.isoCountryCode?.trim().toUpperCase() ?? '';
          city = [locality, country].where((e) => e.isNotEmpty).join(', ');
          debugPrint('[$_tag][LOCATION] reverseGeocode city=$city countryCode=$countryCode');
        }
      } catch (error, stackTrace) {
        debugPrint('[$_tag][LOCATION][WARN] reverseGeocode failed: $error');
        debugPrint('[$_tag][LOCATION][STACK] $stackTrace');
      }

      final result = MunibLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        city: city,
        countryCode: countryCode,
      );
      debugPrint('[$_tag][LOCATION] SUCCESS city=${result.city} countryCode=${result.countryCode}');
      return result;
    } catch (error, stackTrace) {
      debugPrint('[$_tag][LOCATION][EXCEPTION] $error');
      debugPrint('[$_tag][LOCATION][STACK] $stackTrace');
      rethrow;
    }
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
