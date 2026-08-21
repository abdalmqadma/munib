import 'dart:convert';

import 'package:http/http.dart' as http;

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

DATE SAFETY RULES:
- Never label returned rows as day 1, day 2, day 3 merely because they are the first, second or third rows you reconstructed.
- A Gregorian day number must come from that row itself, or from a strongly anchored consecutive sequence visible in OCR.
- If two rows are claimed to be consecutive Gregorian dates but prayer times jump unrealistically, the date inference is wrong. In that case return date=null rather than guessing.
- For consecutive days, sunrise, fajr, maghrib and isha normally change by only a few minutes, not tens of minutes.
''',
          },
          {
            'role': 'user',
            'content': '''LINE-NUMBERED OCR TEXT:
$numberedLines

ALL TIME-LIKE TOKENS DETECTED LOCALLY:
${timeTokens.join(', ')}

Reconstruct as many actual timetable rows as the OCR supports. Prefer incomplete rows with null fields over dropping a real day entirely.
Do NOT manufacture sequential dates from row order. If date evidence is weak, use null.''',
          },
        ],
        'temperature': 0,
        'response_format': {'type': 'json_object'},
      });

      return _sanitizePrayerRows(_extractPrayerArray(data));
    } catch (e) {
      print('Error structuring OCR text: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchPrayerTimesByLocation(
    String cityAndCountry,
  ) async {
    final value = cityAndCountry.trim();
    if (value.isEmpty ||
        value == 'Location disabled' ||
        value.startsWith('Permission denied') ||
        value == 'Error fetching location' ||
        value == 'Unknown Location') {
      return [];
    }

    try {
      final parts = value.split(',').map((e) => e.trim()).toList();
      final city = parts.first;
      final country = parts.length > 1 ? parts.sublist(1).join(', ') : 'Palestine';
      final now = DateTime.now();

      final uri = Uri.https(
        'api.aladhan.com',
        '/v1/calendarByCity/${now.year}/${now.month}',
        {
          'city': city,
          'country': country,
          'method': '5',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['data'] is! List) return [];

      final result = <Map<String, dynamic>>[];
      for (final entry in decoded['data'] as List) {
        if (entry is! Map) continue;
        final timings = entry['timings'];
        final date = entry['date'];
        if (timings is! Map || date is! Map) continue;

        final gregorian = date['gregorian'];
        if (gregorian is! Map) continue;
        final isoDate = _alAdhanDateToIso(gregorian['date']?.toString());
        if (isoDate == null) continue;

        result.add({
          'date': isoDate,
          'fajr': _cleanApiTime(timings['Fajr']),
          'sunrise': _cleanApiTime(timings['Sunrise']),
          'dhuhr': _cleanApiTime(timings['Dhuhr']),
          'asr': _cleanApiTime(timings['Asr']),
          'maghrib': _cleanApiTime(timings['Maghrib']),
          'isha': _cleanApiTime(timings['Isha']),
        });
      }

      return result;
    } catch (e) {
      print('Error fetching prayer times by location: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _sanitizePrayerRows(
    List<Map<String, dynamic>> rows,
  ) {
    final cleaned = <Map<String, dynamic>>[];

    for (final original in rows) {
      final row = Map<String, dynamic>.from(original);
      final validTimes = <int>[];
      for (final key in const ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']) {
        final minutes = _timeToMinutes(row[key]?.toString());
        if (minutes != null) validTimes.add(minutes);
      }

      if (validTimes.length < 4) continue;

      var ordered = true;
      for (var i = 1; i < validTimes.length; i++) {
        if (validTimes[i] <= validTimes[i - 1]) {
          ordered = false;
          break;
        }
      }
      if (!ordered) continue;

      cleaned.add(row);
    }

    for (var i = 1; i < cleaned.length; i++) {
      final previousDate = DateTime.tryParse(cleaned[i - 1]['date']?.toString() ?? '');
      final currentDate = DateTime.tryParse(cleaned[i]['date']?.toString() ?? '');
      if (previousDate == null || currentDate == null) continue;

      final dayDiff = currentDate.difference(previousDate).inDays;
      if (dayDiff != 1) continue;

      var suspicious = false;
      for (final key in const ['fajr', 'sunrise', 'maghrib', 'isha']) {
        final a = _timeToMinutes(cleaned[i - 1][key]?.toString());
        final b = _timeToMinutes(cleaned[i][key]?.toString());
        if (a == null || b == null) continue;
        if ((a - b).abs() > 15) {
          suspicious = true;
          break;
        }
      }

      if (suspicious) {
        cleaned[i - 1]['date'] = '';
        cleaned[i]['date'] = '';
      }
    }

    return cleaned;
  }

  int? _timeToMinutes(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }

  String _cleanApiTime(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    final match = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(text);
    if (match == null) return '';
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) return '';
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String? _alAdhanDateToIso(String? value) {
    if (value == null) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
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
