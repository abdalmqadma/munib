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

      final data = await _apiClient.chatCompletion({
        'model': 'openai/gpt-oss-120b',
        'messages': [
          {
            'role': 'system',
            'content': '''
You convert OCR text from an Arabic Ramadan Imsakia into structured prayer days.
Return an object with a "days" array containing one object for every day that can be reliably identified.
Never invent a date or prayer time. If a value is missing or unreadable, return null.
Use the second Fajr adhan when the timetable contains multiple Fajr entries.
Convert Arabic and Persian digits to English digits.
Times must be HH:mm in 24-hour format.
Keep the date as YYYY-MM-DD when the year/month/day can be determined.
Do not use unrelated numbers such as page numbers as prayer times.
''',
          },
          {
            'role': 'user',
            'content': '''OCR TEXT:
$normalizedText

TIME-LIKE TOKENS FOUND BY LOCAL PARSER:
${timeTokens.join(', ')}''',
          },
        ],
        'temperature': 0,
        'response_format': _prayerSchema(),
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
            'role': 'user',
            'content':
                'Generate prayer times for $city for June 2026. Return an object with a "days" array. '
                'Use Adhan Thani for fajr. Do not invent values that cannot be reliably determined.',
          },
        ],
        'temperature': 0.1,
        'response_format': _prayerSchema(),
      });

      return _extractPrayerArray(data);
    } catch (e) {
      print('Error fetching prayer times by location: $e');
      return [];
    }
  }

  Map<String, dynamic> _prayerSchema() {
    return {
      'type': 'json_schema',
      'json_schema': {
        'name': 'imsakia_prayer_days',
        'strict': true,
        'schema': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'days': {
              'type': 'array',
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'properties': {
                  'date': {'type': ['string', 'null']},
                  'fajr': {'type': ['string', 'null']},
                  'sunrise': {'type': ['string', 'null']},
                  'dhuhr': {'type': ['string', 'null']},
                  'asr': {'type': ['string', 'null']},
                  'maghrib': {'type': ['string', 'null']},
                  'isha': {'type': ['string', 'null']},
                },
                'required': [
                  'date',
                  'fajr',
                  'sunrise',
                  'dhuhr',
                  'asr',
                  'maghrib',
                  'isha',
                ],
              },
            },
          },
          'required': ['days'],
        },
      },
    };
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
    // Keep backward compatibility if a non-schema response ever returns an array.
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
