import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ImsakiaExtractionResult {
  final List<Map<String, dynamic>> days;
  final bool requiresUserReview;
  final List<Map<String, dynamic>> reviewRows;
  final String? reviewMessage;

  const ImsakiaExtractionResult({
    required this.days,
    required this.requiresUserReview,
    required this.reviewRows,
    this.reviewMessage,
  });
}

class LocationPrayerTimesResult {
  final List<Map<String, dynamic>> days;
  final String timezone;

  const LocationPrayerTimesResult({
    required this.days,
    required this.timezone,
  });
}

class AIService {
  static const String _imsakiaApiBaseUrl = 'https://munib-ocr-api.dockhosting.dev';

  Future<ImsakiaExtractionResult> extractImsakiaFromImage(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_imsakiaApiBaseUrl/extract'),
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }

    request.headers['Accept'] = 'application/json';
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamed = await request.send().timeout(const Duration(minutes: 3));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      String message = 'Imsakia API returned ${response.statusCode}';
      try {
        final body = jsonDecode(response.body);
        final detail = body is Map ? body['detail'] : null;
        if (detail != null && detail.toString().trim().isNotEmpty) {
          message = detail.toString();
        }
      } catch (_) {}
      throw HttpException(message);
    }

    final body = jsonDecode(response.body);
    if (body is! Map || body['success'] != true || body['days'] is! List) {
      throw const FormatException('Invalid Imsakia API response');
    }

    final days = <Map<String, dynamic>>[];
    for (final raw in body['days'] as List) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      days.add({
        'fajr': (item['fajr'] ?? '').toString(),
        'sunrise': (item['sunrise'] ?? '').toString(),
        'dhuhr': (item['dhuhr'] ?? '').toString(),
        'asr': (item['asr'] ?? '').toString(),
        'maghrib': (item['maghrib'] ?? '').toString(),
        'isha': (item['isha'] ?? '').toString(),
        'row': item['row'],
        'reconstructed': item['reconstructed'] == true,
        'review_required': item['review_required'] == true || item['reconstructed'] == true,
        'reconstruction_source': item['reconstruction_source'],
      });
    }

    final reviewRows = <Map<String, dynamic>>[];
    if (body['review_rows'] is List) {
      for (final raw in body['review_rows'] as List) {
        if (raw is Map) reviewRows.add(Map<String, dynamic>.from(raw));
      }
    }

    for (final review in reviewRows) {
      final row = review['row'];
      if (row is int && row > 0 && row <= days.length) {
        days[row - 1]['review_required'] = true;
      }
    }

    return ImsakiaExtractionResult(
      days: days,
      requiresUserReview: body['requires_user_review'] == true || reviewRows.isNotEmpty,
      reviewRows: reviewRows,
      reviewMessage: body['review_message']?.toString(),
    );
  }

  Future<List<Map<String, dynamic>>> structurePrayerTimesFromImage(File imageFile) async {
    final result = await extractImsakiaFromImage(imageFile);
    return result.days;
  }

  Future<LocationPrayerTimesResult> fetchPrayerTimesForLocation(
    double latitude,
    double longitude, {
    DateTime? month,
  }) async {
    final target = month ?? DateTime.now();
    final uri = Uri.https(
      'api.aladhan.com',
      '/v1/calendar/${target.year}/${target.month}',
      {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'method': '3',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw HttpException('Prayer API returned ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['code'] != 200 || body['data'] is! List) {
      throw const FormatException('Invalid prayer API response');
    }

    String cleanTime(dynamic value) {
      final text = (value ?? '').toString();
      final match = RegExp(r'\b([01]?\d|2[0-3]):[0-5]\d\b').firstMatch(text);
      return match?.group(0)?.padLeft(5, '0') ?? '';
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
      if (timezone.isEmpty) timezone = (meta['timezone'] ?? '').toString().trim();

      final date = (gregorian['date'] ?? '').toString();
      final parts = date.split('-');
      final isoDate = parts.length == 3 ? '${parts[2]}-${parts[1]}-${parts[0]}' : '';

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

    return LocationPrayerTimesResult(
      days: result.where((e) => (e['date'] as String).isNotEmpty).toList(),
      timezone: timezone,
    );
  }

  Future<List<Map<String, dynamic>>> fetchPrayerTimesByCoordinates(
    double latitude,
    double longitude, {
    DateTime? month,
  }) async {
    return (await fetchPrayerTimesForLocation(
      latitude,
      longitude,
      month: month,
    ))
        .days;
  }

  Future<List<Map<String, dynamic>>> fetchPrayerTimesByLocation(String city) async => [];

  Future<List<Map<String, dynamic>>> structurePrayerTimes(String rawText) async => [];
}
