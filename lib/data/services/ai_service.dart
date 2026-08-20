import 'dart:convert';

import 'imsakia_parser.dart';
import 'munib_api_client.dart';

class AIService {
  final MunibApiClient _apiClient = MunibApiClient();
  final ImsakiaParser _parser = ImsakiaParser();

  Future<List<Map<String, dynamic>>> structurePrayerTimes(
    String rawText,
  ) async {
    if (rawText.trim().isEmpty) return [];

    try {
      final normalizedText = _parser.normalizeOcrText(rawText);
      final timeTokens = _parser.extractTimeTokens(normalizedText);
      final numberedLines = normalizedText
          .split('\n')
          .asMap()
          .entries
          .map((entry) => '${entry.key + 1}: ${entry.value}')
          .join('\n');

      final data = await _apiClient.chatCompletion({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {
            'role': 'system',
            'content': '''
You reconstruct an Arabic Ramadan Imsakia table from noisy OCR.
Return ONLY valid JSON using exactly this top-level shape:
{"days":[{"date":"YYYY-MM-DD or null","fajr":"HH:mm or null","sunrise":"HH:mm or null","dhuhr":"HH:mm or null","asr":"HH:mm or null","maghrib":"HH:mm or null","isha":"HH:mm or null"}]}
Do not use Markdown or explanations.

IMPORTANT TABLE RULES:
- Preserve table rows. One visible timetable day/row should become one item in "days".
- Do NOT return only the cleanest rows. Include every day/row that can be identified from a day number, weekday, Hijri/Gregorian date fragment, or a coherent run of prayer times.
- If a row is identifiable but one or more fields are unreadable, include the row and set only those unreadable fields to null.
- Keep rows in the same order as the source image.
- Never invent a missing prayer time or date.
- If the timetable shows two Fajr entries, use the second Fajr adhan for "fajr".
- Convert Arabic and Persian digits to English digits.
- Times must be HH:mm in 24-hour format.
- Keep "date" as YYYY-MM-DD only when year/month/day are actually recoverable from the timetable. Otherwise use null.
- Never infer today's date or the current year from the device.
- Ignore page numbers, social media text, decorative numbers, and headings.
- Prayer column order is normally: fajr, sunrise, dhuhr, asr, maghrib, isha. Use headings/context to verify it.
- A row with several prayer-like times is more important than unrelated text on the same OCR line.
''',
          },
          {
            'role': 'user',
            'content': '''LINE-NUMBERED OCR TEXT:
$numberedLines

ALL TIME-LIKE TOKENS DETECTED LOCALLY:
${timeTokens.join(', ')}

Reconstruct as many actual timetable rows as the OCR supports. Prefer incomplete rows with null fields over dropping a real day entirely.''',
          },
        ],
        'temperature': 0,
        'response_format': {'type': 'json_object'},
      });

      return _extractPrayerArray(data);
    } catch (e) {
      print('Error structuring OCR text: $e');
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
            'role': 'system',
            'content':
                'Return ONLY a valid JSON object with a "days" array. Do not use Markdown.',
          },
          {
            'role': 'user',
            'content':
                'Generate prayer times for $city for June 2026. Use Adhan Thani for fajr. Do not invent values that cannot be reliably determined.',
          },
        ],
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
      });

      return _extractPrayerArray(data);
    } catch (e) {
      print('Error fetching prayer times by location: $e');
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
      final list = _extractDaysList(decoded);
      if (list != null) {
        return list.whereType<Map>().map(_normalizePrayerDay).toList();
      }
    } catch (_) {
      final objectMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(cleaned);
      if (objectMatch != null) {
        try {
          final decoded = jsonDecode(objectMatch.group(0)!);
          final list = _extractDaysList(decoded);
          if (list != null) {
            return list.whereType<Map>().map(_normalizePrayerDay).toList();
          }
        } catch (_) {}
      }
    }

    return [];
  }

  List<dynamic>? _extractDaysList(dynamic decoded) {
    if (decoded is Map && decoded['days'] is List) {
      return decoded['days'] as List<dynamic>;
    }
    if (decoded is List) return decoded;
    return null;
  }

  Map<String, dynamic> _normalizePrayerDay(Map item) {
    const keys = [
      'date',
      'fajr',
      'sunrise',
      'dhuhr',
      'asr',
      'maghrib',
      'isha',
    ];

    final result = <String, dynamic>{};
    for (final key in keys) {
      final value = item[key];
      result[key] = value == null ? '' : value.toString().trim();
    }
    return result;
  }
}
