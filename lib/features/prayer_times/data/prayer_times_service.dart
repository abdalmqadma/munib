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

  String? get fallbackMethodSlug {
    switch (method) {
      case 0:
        return 'jafari';
      case 1:
        return 'karachi';
      case 2:
        return 'isna';
      case 3:
        return 'mwl';
      case 4:
        return 'umm-al-qura';
      case 5:
        return 'egyptian';
      default:
        return null;
    }
  }

  Map<String, int> get tuneOffsets {
    final raw = tune;
    if (raw == null || raw.trim().isEmpty) return const {};
    final values = raw.split(',').map((value) => int.tryParse(value.trim()) ?? 0).toList();
    if (values.length < 8) return const {};
    return {
      'fajr': values[1],
      'sunrise': values[2],
      'dhuhr': values[3],
      'asr': values[4],
      'maghrib': values[5],
      'isha': values[7],
    };
  }

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
  static const _headers = <String, String>{
    'Accept': 'application/json',
    'User-Agent': 'MunibPrayerApp/1.0 (prayer times)',
  };

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

    Object? primaryError;
    try {
      return await _fetchFromAlAdhan(
        latitude: latitude,
        longitude: longitude,
        target: target,
        profile: profile,
      );
    } catch (error) {
      primaryError = error;
    }

    try {
      return await _fetchFromESalah(
        latitude: latitude,
        longitude: longitude,
        target: target,
        profile: profile,
      );
    } catch (fallbackError) {
      throw HttpException(
        'All prayer-time providers failed. '
        'Primary: $primaryError; fallback: $fallbackError',
      );
    }
  }

  Future<LocationPrayerTimesResult> _fetchFromAlAdhan({
    required double latitude,
    required double longitude,
    required DateTime target,
    required PrayerCalculationProfile profile,
  }) async {
    final query = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'method': profile.method.toString(),
      'school': profile.school.toString(),
    };

    // Tune is applied locally below. Keeping it out of the request makes the
    // calendar request compatible with more AlAdhan deployments/proxies and
    // gives both providers identical adjustment behavior.
    final uri = Uri.https(
      'api.aladhan.com',
      '/v1/calendar/${target.year}/${target.month}',
      query,
    );

    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException('AlAdhan returned ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Invalid AlAdhan response');
    }
    final body = Map<String, dynamic>.from(decoded);
    if (body['code'] != 200 || body['data'] is! List) {
      throw const FormatException('Invalid AlAdhan prayer data');
    }

    String timezone = '';
    final result = <Map<String, dynamic>>[];

    for (final raw in body['data'] as List) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final timings = Map<String, dynamic>.from(item['timings'] as Map? ?? {});
      final dateMap = Map<String, dynamic>.from(item['date'] as Map? ?? {});
      final gregorian = Map<String, dynamic>.from(dateMap['gregorian'] as Map? ?? {});
      final meta = Map<String, dynamic>.from(item['meta'] as Map? ?? {});

      if (timezone.isEmpty) {
        timezone = (meta['timezone'] ?? '').toString().trim();
      }

      final parts = (gregorian['date'] ?? '').toString().split('-');
      final isoDate = parts.length == 3 ? '${parts[2]}-${parts[1]}-${parts[0]}' : '';
      if (isoDate.isEmpty) continue;

      result.add(_buildDay(
        date: isoDate,
        fajr: timings['Fajr'],
        sunrise: timings['Sunrise'],
        dhuhr: timings['Dhuhr'],
        asr: timings['Asr'],
        maghrib: timings['Maghrib'],
        isha: timings['Isha'],
        offsets: profile.tuneOffsets,
      ));
    }

    final valid = result.where(_isValidDay).toList();
    if (valid.isEmpty) {
      throw const FormatException('AlAdhan returned no usable prayer days');
    }

    return LocationPrayerTimesResult(days: valid, timezone: timezone);
  }

  Future<LocationPrayerTimesResult> _fetchFromESalah({
    required double latitude,
    required double longitude,
    required DateTime target,
    required PrayerCalculationProfile profile,
  }) async {
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    final dates = [
      for (var day = 1; day <= lastDay; day++)
        DateTime(target.year, target.month, day),
    ];

    final results = <Map<String, dynamic>>[];
    var timezone = '';

    // Five requests at a time keeps the fallback quick while staying well
    // below the public API's 60 requests/minute limit for a single month.
    for (var start = 0; start < dates.length; start += 5) {
      final end = (start + 5).clamp(0, dates.length);
      final batch = dates.sublist(start, end);
      final responses = await Future.wait(
        batch.map(
          (date) => _fetchESalahDay(
            latitude: latitude,
            longitude: longitude,
            date: date,
            profile: profile,
          ),
        ),
      );

      for (final response in responses) {
        timezone = timezone.isEmpty ? response.timezone : timezone;
        if (_isValidDay(response.day)) results.add(response.day);
      }
    }

    if (results.isEmpty) {
      throw const FormatException('eSalah returned no usable prayer days');
    }

    results.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return LocationPrayerTimesResult(days: results, timezone: timezone);
  }

  Future<_ESalahDayResult> _fetchESalahDay({
    required double latitude,
    required double longitude,
    required DateTime date,
    required PrayerCalculationProfile profile,
  }) async {
    final dateText = _isoDate(date);
    final query = <String, String>{
      'lat': latitude.toString(),
      'lng': longitude.toString(),
      'date': dateText,
      'madhab': profile.school == 1 ? 'hanafi' : 'standard',
    };
    final method = profile.fallbackMethodSlug;
    if (method != null) query['method'] = method;

    final uri = Uri.https('esalah.com', '/api/v1/times', query);
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw HttpException('eSalah returned ${response.statusCode} for $dateText');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Invalid eSalah response');
    }
    final body = Map<String, dynamic>.from(decoded);
    final times = body['times'] is Map
        ? Map<String, dynamic>.from(body['times'] as Map)
        : body;
    final location = body['location'] is Map
        ? Map<String, dynamic>.from(body['location'] as Map)
        : <String, dynamic>{};

    final timezone = (location['timezone'] ?? body['timezone'] ?? '').toString().trim();
    final responseDate = (body['date'] ?? dateText).toString().trim();

    return _ESalahDayResult(
      timezone: timezone,
      day: _buildDay(
        date: responseDate,
        fajr: times['Fajr'] ?? times['fajr'],
        sunrise: times['Sunrise'] ?? times['sunrise'],
        dhuhr: times['Dhuhr'] ?? times['dhuhr'],
        asr: times['Asr'] ?? times['asr'],
        maghrib: times['Maghrib'] ?? times['maghrib'],
        isha: times['Isha'] ?? times['isha'],
        offsets: profile.tuneOffsets,
      ),
    );
  }

  Map<String, dynamic> _buildDay({
    required String date,
    required dynamic fajr,
    required dynamic sunrise,
    required dynamic dhuhr,
    required dynamic asr,
    required dynamic maghrib,
    required dynamic isha,
    required Map<String, int> offsets,
  }) {
    return {
      'date': date,
      'fajr': _adjustTime(_cleanTime(fajr), offsets['fajr'] ?? 0),
      'sunrise': _adjustTime(_cleanTime(sunrise), offsets['sunrise'] ?? 0),
      'dhuhr': _adjustTime(_cleanTime(dhuhr), offsets['dhuhr'] ?? 0),
      'asr': _adjustTime(_cleanTime(asr), offsets['asr'] ?? 0),
      'maghrib': _adjustTime(_cleanTime(maghrib), offsets['maghrib'] ?? 0),
      'isha': _adjustTime(_cleanTime(isha), offsets['isha'] ?? 0),
    };
  }

  bool _isValidDay(Map<String, dynamic> day) {
    if ((day['date'] ?? '').toString().trim().isEmpty) return false;
    for (final key in const ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      if ((day[key] ?? '').toString().trim().isEmpty) return false;
    }
    return true;
  }

  String _cleanTime(dynamic value) {
    final match = RegExp(r'\b([01]?\d|2[0-3]):[0-5]\d\b')
        .firstMatch((value ?? '').toString());
    return match?.group(0)?.padLeft(5, '0') ?? '';
  }

  String _adjustTime(String value, int minutes) {
    if (value.isEmpty || minutes == 0) return value;
    final parts = value.split(':');
    if (parts.length != 2) return value;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return value;

    var total = hour * 60 + minute + minutes;
    total %= 24 * 60;
    if (total < 0) total += 24 * 60;
    final adjustedHour = total ~/ 60;
    final adjustedMinute = total % 60;
    return '${adjustedHour.toString().padLeft(2, '0')}:${adjustedMinute.toString().padLeft(2, '0')}';
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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

class _ESalahDayResult {
  final Map<String, dynamic> day;
  final String timezone;

  const _ESalahDayResult({
    required this.day,
    required this.timezone,
  });
}

/// Temporary compatibility name while older screens migrate to PrayerTimesService.
@Deprecated('Use PrayerTimesService instead.')
class AIService extends PrayerTimesService {}
