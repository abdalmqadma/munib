import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
    final requestBody = <String, dynamic>{
      'type': 'chat_completion',
      'payload': payload,
    };

    // DEBUG: persist the exact JSON body that is sent to the Worker.
    // This file contains the OCR-derived user message, system prompt, model,
    // temperature and response format exactly as transmitted by the app.
    await _writeLastAiRequest(requestBody);

    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: const {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody),
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

  Future<void> _writeLastAiRequest(Map<String, dynamic> requestBody) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/last_ai_request.json');
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(
        encoder.convert(requestBody),
        encoding: utf8,
        flush: true,
      );
      debugPrint('[MUNIB] Exact AI request saved to: ${file.path}');
    } catch (e) {
      // Debug persistence must never block the real API request.
      debugPrint('[MUNIB] Could not save AI request debug file: $e');
    }
  }
}
