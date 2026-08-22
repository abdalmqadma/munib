import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
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

class AIService {
  static const String _imsakiaApiBaseUrl = 'https://munib-ocr-api.dockhosting.dev';

  String get _apiKey => (dotenv.env['GROQ_API_KEY'] ?? '').trim();

  Future<ImsakiaExtractionResult> extractImsakiaFromImage(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_imsakiaApiBaseUrl/extract'),
    );

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

  /// Free, deterministic location-based prayer times. No Groq key is needed.
  /// Uses the current Gregorian month and the Muslim World League method.
  Future<List<Map<String, dynamic>>> fetchPrayerTimesByCoordinates(
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

    final result = <Map<String, dynamic>>[];
    for (final raw in body['data'] as List) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final timings = Map<String, dynamic>.from(item['timings'] as Map? ?? {});
      final gregorian = Map<String, dynamic>.from(
        (item['date'] as Map?)?['gregorian'] as Map? ?? {},
      );
      final date = (gregorian['date'] ?? '').toString(); // DD-MM-YYYY
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
    return result.where((e) => (e['date'] as String).isNotEmpty).toList();
  }

  // Kept for older callers. Location fetching should use coordinates instead.
  Future<List<Map<String, dynamic>>> fetchPrayerTimesByLocation(String city) async => [];

  Future<List<Map<String, dynamic>>> structurePrayerTimes(String rawText) async {
    if (_apiKey.isEmpty || rawText.trim().isEmpty) return [];
    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'user', 'content': 'Convert to JSON array: $rawText'}
          ]
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _extractJsonArray(data['choices']?[0]['message']?['content'] as String?);
      }
    } catch (_) {}
    return [];
  }

  List<Map<String, dynamic>> _extractJsonArray(String? content) {
    if (content == null) return [];
    final match = RegExp(r'\[\s*\{.*\}\s*\]', dotAll: true).firstMatch(content);
    if (match == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(match.group(0)!));
    } catch (_) {
      return [];
    }
  }
}
