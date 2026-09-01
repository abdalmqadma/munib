import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

    final isGazaStrip = latitude >= 31.20 &&
        latitude <= 31.65 &&
        longitude >= 34.15 &&
        longitude <= 34.65;
    if (isGazaStrip) return forCountry('PS');

    return forCountry(null);
  }
}

class PrayerTimesService {
  static const _tag = 'MUNIB_IMSAKIA';

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

    final query = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'method': profile.method.toString(),
      'school': profile.school.toString(),
    };
    if (profile.tune != null) query['tune'] = profile.tune!;

    final uri = Uri.https(
      'api.aladhan.com',
      '/v1/calendar/${target.year}/${target.month}',
      query,
    );

    debugPrint('[$_tag][PRAYER_API] START lat=$latitude lon=$longitude country=${countryCode ?? ''} month=${target.year}-${target.month} method=${profile.method} school=${profile.school} tune=${profile.tune ?? 'none'}');
    debugPrint('[$_tag][PRAYER_API] GET $uri');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      debugPrint('[$_tag][PRAYER_API] HTTP ${response.statusCode} bodyBytes=${response.bodyBytes.length}');

      if (response.statusCode != 200) {
        final preview = response.body.length > 1000
            ? response.body.substring(0, 1000)
            : response.body;
        debugPrint('[$_tag][PRAYER_API][ERROR] response=$preview');
        throw HttpException('Prayer API returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('[$_tag][PRAYER_API][ERROR] decoded response is ${decoded.runtimeType}, expected Map');
        throw const FormatException('Invalid prayer API response type');
      }
      final body = decoded;
      debugPrint('[$_tag][PRAYER_API] apiCode=${body['code']} dataType=${body['data'].runtimeType}');

      if (body['code'] != 200 || body['data'] is! List) {
        final preview = response.body.length > 1000
            ? response.body.substring(0, 1000)
            : response.body;
        debugPrint('[$_tag][PRAYER_API][ERROR] invalid payload=$preview');
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

        result.add({
          'date': isoDate,
          'fajr': cleanTime(timings['Fajr']),
          'sunrise': cleanTime(timings['Sunrise']),
          'dhuhr': cleanTime(timings['Dhuhr']),
          'asr': cleanTime(timings['Asr']),
          'maghrib': cleanTime(timings['Maghrib']),
          'isha': cleanTime(timings['Isha']),
        });
      }

      final validDays =
          result.where((e) => (e['date'] as String).isNotEmpty).toList();
      debugPrint('[$_tag][PRAYER_API] SUCCESS days=${validDays.length} timezone=$timezone first=${validDays.isEmpty ? 'none' : validDays.first['date']} last=${validDays.isEmpty ? 'none' : validDays.last['date']}');

      return LocationPrayerTimesResult(
        days: validDays,
        timezone: timezone,
      );
    } catch (error, stackTrace) {
      debugPrint('[$_tag][PRAYER_API][EXCEPTION] $error');
      debugPrint('[$_tag][PRAYER_API][STACK] $stackTrace');
      rethrow;
    }
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

@Deprecated('Use PrayerTimesService instead.')
class AIService extends PrayerTimesService {}
