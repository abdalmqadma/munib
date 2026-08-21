import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AIService {
  String get _apiKey => (dotenv.env['GROQ_API_KEY'] ?? '').trim();

  Future<List<Map<String, dynamic>>> structurePrayerTimesFromImage(File imageFile) async {
    if (_apiKey.isEmpty) return [];
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'qwen/qwen3.6-27b',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Extract all prayer times from this Arabic Imsakiah image. Return ONLY a JSON array. Keys: "date" (YYYY-MM-DD), "fajr" (Take Adhan Thani), "sunrise", "dhuhr", "asr", "maghrib", "isha". Times in HH:mm.'
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                }
              ]
            }
          ],
          'max_tokens': 4096,
          'temperature': 0.1,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]['message']?['content'] as String?;
        return _extractJsonArray(content);
      }
    } catch (_) {}
    return [];
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
