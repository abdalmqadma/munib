import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client for Munib's backend Worker.
///
/// The Groq API key must never be stored in the Flutter application.
/// The Cloudflare Worker keeps the key as a server-side secret and forwards
/// approved Groq requests to the Groq API.
class MunibApiClient {
  static const String _baseUrl =
      'https://muneeb-api.abd810166.workers.dev';

  Future<Map<String, dynamic>> chatCompletion(
    Map<String, dynamic> payload,
  ) async {
    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: const {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'type': 'chat_completion',
            'payload': payload,
          }),
        )
        .timeout(const Duration(seconds: 90));

    final dynamic decoded = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? (decoded['error'] ?? 'Backend request failed').toString()
          : 'Backend request failed (${response.statusCode})';
      throw Exception(message);
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backend returned an invalid JSON object.');
    }

    return decoded;
  }
}
