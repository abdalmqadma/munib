import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class LocationPrayerTimesResult {
  final List<Map<String, dynamic>> days;
  final String timezone;

  const LocationPrayerTimesResult({
    required this.days,
    required this.timezone,
  });
}

class PrayerCalculationProfile {
  final int method;
  final int school;
  final String? tune;

  const PrayerCalculationProfile({
    required this.method,
    this.school = 0,
    this.tune,
  });

  /// Selects the calculation authority normally used in the detected country.
  static PrayerCalculationProfile forCountry(String? countryCode) {
    switch ((countryCode ?? '').trim().toUpperCase()) {
      // Palestine: Egyptian Survey angles with local Gaza timetable offsets.
      // tune order: Imsak,Fajr,Sunrise,Dhuhr,Asr,Maghrib,Sunset,Isha,Midnight.
      case 'PS':
        return const PrayerCalculationProfile(
          method: 5,
          tune: '0,0,0,-1,-1,2,0,-1,0',
        );
      case 'EG':
      case 'SD':
        return const PrayerCalculationProfile(method: 5);
      case 'SA':
        return const PrayerCalculationProfile(method: 4);
      case 'AE':
        return const PrayerCalculationProfile(method: 16);
      case 'KW':
        return const PrayerCalculationProfile(method: 9);
      case 'QA':
        return const PrayerCalculationProfile(method: 10);
      case 'BH':
      case 'OM':
      case 'YE':
        return const PrayerCalculationProfile(method: 8);
      case 'JO':
        return const PrayerCalculationProfile(method: 23);
      case 'TR':
        return const PrayerCalculationProfile(method: 13);
      case 'RU':
        return const PrayerCalculationProfile(method: 14);
      case 'PK':
      case 'IN':
      case 'BD':
      case 'AF':
        return const PrayerCalculationProfile(method: 1, school: 1);
      case 'US':
      case 'CA':
        return const PrayerCalculationProfile(method: 2);
      case 'MY':
        return const PrayerCalculationProfile(method: 17);
      case 'SG':
        return const PrayerCalculationProfile(method: 11);
      case 'ID':
        return const PrayerCalculationProfile(method: 20);
      case 'TN':
        return const PrayerCalculationProfile(method: 18);
      case 'DZ':
        return const PrayerCalculationProfile(method: 19);
      case 'MA':
        return const PrayerCalculationProfile(method: 21);
      case 'PT':
        return const PrayerCalculationProfile(method: 22);
      case 'FR':
        return const PrayerCalculationProfile(method: 12);
      default:
        return const PrayerCalculationProfile(method: 3);
    }
  }

  static PrayerCalculationProfile forLocation({
    required double latitude,
    required double longitude,
    String? countryCode,
  }) {
    final code = (countryCode ?? '').trim().toUpperCase();
    if (code.isNotEmpty) return forCountry(code);

    // Reverse geocoding can be unavailable even while GPS and the prayer API
    // work. Keep Gaza on its calibrated profile in that case as well.
    final isGazaStrip = latitude >= 31.20 &&
        latitude <= 31.65 &&
        longitude >= 34.15 &&
        longitude <= 34.65;
    if (isGazaStrip) return forCountry('PS');

    return forCountry(null);
  }
}

class PrayerTimesService {
  Future<LocationPrayerTimesResult> fetchPrayerTimesForLocation(
    double latitude,
    double longitude, {
    DateTime? month,
    String? countryCode,
  }) async {
    final target = month ?? DateTime.now();
    final profile = PrayerCalculationProfile.forLocation(
      latitude: latitude,
      longitude: longitude,
      countryCode: countryCode,
    );

    final regionalQuery = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'method': profile.method.toString(),
      'school': profile.school.toString(),
    };
    if (profile.tune != null) regionalQuery['tune'] = profile.tune!;

    Object? regionalError;
    try {
      return await _fetchCalendar(target, regionalQuery);
    } catch (error) {
      regionalError = error;
    }

    // This is the exact minimal request shape Munib used before regional
    // profiles were introduced. Keep it as the first compatibility fallback
    // so a fresh install can still obtain a calendar if a proxy/API deployment
    // rejects school/tune or newer method parameters.
    final legacyQuery = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'method': '3',
    };
    Object? legacyError;
    try {
      return await _fetchCalendar(target, legacyQuery);
    } catch (error) {
      legacyError = error;
    }

    // Last resort: let AlAdhan select the calculation method from coordinates.
    // This also protects against a calculation-method id changing upstream.
    final minimalQuery = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
    };
    try {
      return await _fetchCalendar(target, minimalQuery);
    } catch (minimalError) {
      throw HttpException(
        'Prayer calendar failed. regional=$regionalError; '
        'legacy=$legacyError; minimal=$minimalError',
      );
    }
  }

  Future<LocationPrayerTimesResult> _fetchCalendar(
    DateTime target,
    Map<String, String> query,
  ) async {
    final uri = Uri.https(
      'api.aladhan.com',
      '/v1/calendar/${target.year}/${target.month}',
      query,
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw HttpException('Prayer API returned ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Invalid prayer API response');
    }
    final body = Map<String, dynamic>.from(decoded);
    if (body['code'] != 200 || body['data'] is! List) {
      throw const FormatException('Invalid prayer API response');
    }

    String cleanTime(dynamic value) {
      final match = RegExp(
        r'\b([01]?\d|2[0-3]):[0-5]\d\b',
      ).firstMatch((value ?? '').toString());
      return match?.group(0)?.padLeft(5, '0') ?? '';
    }

    String timezone = '';
    final result = <Map<String, dynamic>>[];

    for (final raw in body['data'] as List) {
      if (raw is! Map) continue;

      final item = Map<String, dynamic>.from(raw);
      final timings = Map<String, dynamic>.from(item['timings'] as Map? ?? {});
      final dateMap = Map<String, dynamic>.from(item['date'] as Map? ?? {});
      final gregorian = Map<String, dynamic>.from(
        dateMap['gregorian'] as Map? ?? {},
      );
      final meta = Map<String, dynamic>.from(item['meta'] as Map? ?? {});

      if (timezone.isEmpty) {
        timezone = (meta['timezone'] ?? '').toString().trim();
      }

      final parts = (gregorian['date'] ?? '').toString().split('-');
      final isoDate = parts.length == 3
          ? '${parts[2]}-${parts[1]}-${parts[0]}'
          : '';

      final day = <String, dynamic>{
        'date': isoDate,
        'fajr': cleanTime(timings['Fajr']),
        'sunrise': cleanTime(timings['Sunrise']),
        'dhuhr': cleanTime(timings['Dhuhr']),
        'asr': cleanTime(timings['Asr']),
        'maghrib': cleanTime(timings['Maghrib']),
        'isha': cleanTime(timings['Isha']),
      };
      if (_isUsableDay(day)) result.add(day);
    }

    if (result.isEmpty) {
      throw const FormatException('Prayer API returned no usable days');
    }

    return LocationPrayerTimesResult(days: result, timezone: timezone);
  }

  bool _isUsableDay(Map<String, dynamic> day) {
    for (final key in const [
      'date',
      'fajr',
      'sunrise',
      'dhuhr',
      'asr',
      'maghrib',
      'isha',
    ]) {
      if ((day[key] ?? '').toString().trim().isEmpty) return false;
    }
    return true;
  }

  Future<List<Map<String, dynamic>>> fetchPrayerTimesByCoordinates(
    double latitude,
    double longitude, {
    DateTime? month,
    String? countryCode,
  }) async =>
      (await fetchPrayerTimesForLocation(
        latitude,
        longitude,
        month: month,
        countryCode: countryCode,
      ))
          .days;
}

/// Temporary compatibility name while older screens migrate to PrayerTimesService.
@Deprecated('Use PrayerTimesService instead.')
class AIService extends PrayerTimesService {}
