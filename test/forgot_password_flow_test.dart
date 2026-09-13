import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:munib/features/auth/data/auth_service.dart';

void main() {
  group('forgot password email validation', () {
    test('accepts a normal email', () {
      expect(AuthService.isValidEmail('user@example.com'), isTrue);
    });

    test('trims surrounding whitespace', () {
      expect(AuthService.normalizeEmail('  user@example.com  '), 'user@example.com');
      expect(AuthService.isValidEmail('  user@example.com  '), isTrue);
    });

    test('rejects malformed email values', () {
      expect(AuthService.isValidEmail('user'), isFalse);
      expect(AuthService.isValidEmail('user@'), isFalse);
      expect(AuthService.isValidEmail('@example.com'), isFalse);
    });
  });

  test('browser reset handler verifies and confirms oobCode', () {
    final html = File('website/reset-password/index.html').readAsStringSync();

    expect(html, contains("params.get('oobCode')"));
    expect(html, contains("params.get('apiKey')"));
    expect(html, contains('accounts:resetPassword'));
    expect(html, contains('newPassword: password'));
    expect(html, contains('EXPIRED_OOB_CODE'));
    expect(html, contains('INVALID_OOB_CODE'));
    expect(html, contains('accounts:sendOobCode'));
    expect(html, contains("requestType:'PASSWORD_RESET'"));
  });
}
