import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

class AIService {
  String get _apiKey => (dotenv.env['GROQ_API_KEY'] ?? "").trim();

  Future<List<Map<String, dynamic>>> structurePrayerTimesFromImage(File imageFile) async {
    if (_apiKey.isEmpty) return [];

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    try {
      print("Calling Groq Llama 4 Vision - Full Palestinian Analysis...");
      
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": "meta-llama/llama-4-scout-17b-16e-instruct",
          "messages": [
            {
              "role": "user",
              "content": [
                {
                  "type": "text",
                  "text": """
                  Analyze this Palestinian Imsakiah image and extract ALL prayer time rows.
                  Rules:
                  1. Columns are: Date, Fajr (take Adhan Thani/أذان ثاني), Sunrise, Dhuhr, Asr, Maghrib, Isha.
                  2. If an hour is missing (e.g. :45), infer it from the previous row.
                  3. Return ONLY a valid JSON array of objects.
                  4. Keys: "date" (YYYY-MM-DD), "fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha".
                  5. Format times in 24h HH:mm.
                  """
                },
                {
                  "type": "image_url",
                  "image_url": {
                    "url": "data:image/jpeg;base64,$base64Image"
                  }
                }
              ]
            }
          ],
          "max_tokens": 4096,
          "temperature": 0.1
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String? content = data['choices']?[0]['message']?['content'];
        
        if (content != null) {
          print("AI Raw Content: $content"); // سأطبع الرد لنعرف ماذا يحدث
          
          final RegExp jsonRegex = RegExp(r'\[\s*\{.*\}\s*\]', dotAll: true);
          final match = jsonRegex.firstMatch(content);
          
          if (match != null) {
            return List<Map<String, dynamic>>.from(jsonDecode(match.group(0)!));
          }
        }
      } else {
        print("Groq Error Status: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("AI Exception: $e");
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchPrayerTimesByLocation(String city) async {
    if (_apiKey.isEmpty) return [];
    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {
              "role": "system", 
              "content": "You are a prayer time generator. Return ONLY JSON array."
            },
            {
              "role": "user",
              "content": "Generate JSON array of prayer times for $city for June 2026. Use Adhan Thani for fajr. Keys: date, fajr, sunrise, dhuhr, asr, maghrib, isha."
            }
          ],
          "temperature": 0.2
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String? content = data['choices']?[0]['message']?['content'];
        if (content != null) {
          final RegExp jsonRegex = RegExp(r'\[\s*\{.*\}\s*\]', dotAll: true);
          final match = jsonRegex.firstMatch(content);
          if (match != null) return List<Map<String, dynamic>>.from(jsonDecode(match.group(0)!));
        }
      }
    } catch (e) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> structurePrayerTimes(String rawText) async {
    // Basic text processing
    if (_apiKey.isEmpty || rawText.trim().isEmpty) return [];
    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [{"role": "user", "content": "Convert to JSON array: $rawText"}]
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String? content = data['choices']?[0]['message']?['content'];
        if (content != null) {
          final RegExp jsonRegex = RegExp(r'\[\s*\{.*\}\s*\]', dotAll: true);
          final match = jsonRegex.firstMatch(content);
          if (match != null) return List<Map<String, dynamic>>.from(jsonDecode(match.group(0)!));
        }
      }
    } catch (e) {}
    return [];
  }
}
