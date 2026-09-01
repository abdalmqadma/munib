import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ProfilePhotoService {
  static const _apiBaseUrl = String.fromEnvironment('MUNIB_API_BASE_URL');

  Future<String> upload({
    required User user,
    required Uint8List bytes,
  }) async {
    if (_apiBaseUrl.trim().isEmpty) {
      throw const ProfilePhotoException('missing_api_url');
    }

    if (bytes.isEmpty || bytes.lengthInBytes > 4 * 1024 * 1024) {
      throw const ProfilePhotoException('invalid_photo_size');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const ProfilePhotoException('authentication_required');
    }

    final signatureResponse = await http
        .post(
          Uri.parse(
            '${_apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '')}'
            '/profile-photo/signature',
          ),
          headers: {'Authorization': 'Bearer $idToken'},
        )
        .timeout(const Duration(seconds: 15));

    if (signatureResponse.statusCode != 200) {
      throw ProfilePhotoException(
        'signature_failed_${signatureResponse.statusCode}',
      );
    }

    final signature = jsonDecode(signatureResponse.body) as Map<String, dynamic>;
    final cloudName = signature['cloud_name'] as String?;
    if (cloudName == null || cloudName.isEmpty) {
      throw const ProfilePhotoException('invalid_signature_response');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
    )
      ..fields.addAll({
        'api_key': signature['api_key'].toString(),
        'timestamp': signature['timestamp'].toString(),
        'signature': signature['signature'].toString(),
        'upload_preset': signature['upload_preset'].toString(),
        'public_id': signature['public_id'].toString(),
        'overwrite': 'true',
        'invalidate': 'true',
      })
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: '${user.uid}.jpg',
        ),
      );

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProfilePhotoException('upload_failed_${response.statusCode}');
    }

    final result = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = result['secure_url'] as String?;
    if (secureUrl == null || secureUrl.isEmpty) {
      throw const ProfilePhotoException('missing_photo_url');
    }
    return secureUrl;
  }
}

class ProfilePhotoException implements Exception {
  final String code;
  const ProfilePhotoException(this.code);

  @override
  String toString() => code;
}
