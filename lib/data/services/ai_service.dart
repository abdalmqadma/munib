import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

class AIService {
  String get _apiKey => (dotenv.env['GROQ_API_KEY'] ?? "").trim();

  Future<List<Map<String, dynamic>>> structurePrayerTimesFromImage(File imageFile) async {
    if (_apiKey.isEmpty) return [];

    try {
      print("Testing connection to api.groq.com...");
      final test = await http.get(Uri.parse('https://api.groq.com')).timeout(const Duration(seconds: 10));
      print("Test response: ${test.statusCode}");
    } catch (e) {
      print("Test connection failed: $e");
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // الموديل الوحيد المتاح لـ Vision في حسابك حالياً
    final models = [
      "qwen/qwen3.6-27b",
    ];

    for (String model in models) {
      try {
        print("Trying AI analysis with model: $model...");
        
        final response = await http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            "model": model,
            "messages": [
              {
                "role": "user",
                "content": [
                  {
                    "type": "text",
                    "text": "Extract all prayer times from this Arabic Imsakiah image. Return ONLY a JSON array. Keys: \"date\" (YYYY-MM-DD), \"fajr\" (Take Adhan Thani), \"sunrise\", \"dhuhr\", \"asr\", \"maghrib\", \"isha\". Times in HH:mm."
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
            final RegExp jsonRegex = RegExp(r'\[\s*\{.*\}\s*\]', dotAll: true);
            final match = jsonRegex.firstMatch(content);
            
            if (match != null) {
              print("AI analysis successful with model: $model");
              return List<Map<String, dynamic>>.from(jsonDecode(match.group(0)!));
            }
          }
        } else {
          print("Model $model failed with status: ${response.statusCode} - ${response.body}");
        }
      } catch (e) {
        print("Error with model $model: $e");
      }
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
              "role": "user",
              "content": "Generate JSON array of prayer times for $city for June 2026. Use Adhan Thani for fajr. Keys: date, fajr, sunrise, dhuhr, asr, maghrib, isha. Format HH:mm."
            }
          ],
          "temperature": 0.1
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
