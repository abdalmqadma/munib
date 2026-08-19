import 'dart:convert';
import 'dart:io';

import 'munib_api_client.dart';

class AIService {
  final MunibApiClient _apiClient = MunibApiClient();

  Future<List<Map<String, dynamic>>> structurePrayerTimesFromImage(
    File imageFile,
  ) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Keep the existing vision model for the image workflow.
      const model = 'qwen/qwen3.6-27b';

      final data = await _apiClient.chatCompletion({
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text':
                    'Extract all prayer times from this Arabic Imsakiah image. '
                    'Return ONLY a JSON array. Keys: "date" (YYYY-MM-DD), '
                    '"fajr" (Take Adhan Thani), "sunrise", "dhuhr", "asr", '
                    '"maghrib", "isha". Times in HH:mm. Do not guess values.',
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                },
              },
            ],
          },
        ],
        'max_tokens': 4096,
        'temperature': 0.1,
      });

      return _extractPrayerArray(data);
    } catch (e) {
      print('Error extracting prayer times from image: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchPrayerTimesByLocation(
    String city,
  ) async {
    if (city.trim().isEmpty) return [];

    try {
      final data = await _apiClient.chatCompletion({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {
            'role': 'user',
            'content':
                'Generate a JSON array of prayer times for $city for June 2026. '
                'Use Adhan Thani for fajr. Keys: date, fajr, sunrise, dhuhr, '
                'asr, maghrib, isha. Format HH:mm. Do not guess values that '
                'cannot be reliably determined.',
          },
        ],
        'temperature': 0.1,
      });

      return _extractPrayerArray(data);
    } catch (e) {
      print('Error fetching prayer times by location: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> structurePrayerTimes(
    String rawText,
  ) async {
    if (rawText.trim().isEmpty) return [];

    try {
      final data = await _apiClient.chatCompletion({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {
            'role': 'system',
            'content':
                'Convert OCR text from an Arabic Ramadan timetable into a '
                'JSON array of prayer days. Return only the JSON array. '
                'Keys: date, fajr, sunrise, dhuhr, asr, maghrib, isha. '
                'Times must use HH:mm. Convert Arabic numerals to English '
                'numerals. Never invent or guess a missing value.',
          },
          {
            'role': 'user',
            'content': rawText,
          },
        ],
        'temperature': 0,
      });

      return _extractPrayerArray(data);
    } catch (e) {
      print('Error structuring OCR text: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _extractPrayerArray(
    Map<String, dynamic> data,
  ) {
    final content = data['choices']?[0]?['message']?['content'];
    if (content is! String || content.trim().isEmpty) return [];

    final cleaned = content
        .replaceFirst(RegExp(r'^\s*```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```\s*$'), '')
        .trim();

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {
      // Fall back to extracting a JSON array if the model added extra text.
      final match = RegExp(r'\[\s*\{.*\}\s*\]', dotAll: true)
          .firstMatch(cleaned);
      if (match != null) {
        try {
          final decoded = jsonDecode(match.group(0)!);
          if (decoded is List) {
            return decoded
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          }
        } catch (_) {}
      }
    }

    return [];
  }
}
