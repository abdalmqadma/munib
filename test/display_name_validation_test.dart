import 'package:flutter_test/flutter_test.dart';
import 'package:munib/features/auth/data/auth_service.dart';

void main() {
  group('display name validation', () {
    test('accepts Arabic and English letters with spaces', () {
      expect(AuthService.isValidDisplayName('عبد الهادي'), isTrue);
      expect(AuthService.isValidDisplayName('Abd Alhady'), isTrue);
      expect(AuthService.isValidDisplayName('عبد Alhady'), isTrue);
    });

    test('normalizes surrounding and repeated whitespace', () {
      expect(
        AuthService.normalizeDisplayName('  عبد   الهادي  '),
        'عبد الهادي',
      );
    });

    test('rejects empty and one-letter names', () {
      expect(AuthService.isValidDisplayName(''), isFalse);
      expect(AuthService.isValidDisplayName('   '), isFalse);
      expect(AuthService.isValidDisplayName('ع'), isFalse);
    });

    test('rejects digits, punctuation, markup, and emoji', () {
      expect(AuthService.isValidDisplayName('Abd123'), isFalse);
      expect(AuthService.isValidDisplayName('Abd-Alhady'), isFalse);
      expect(
        AuthService.isValidDisplayName("<script>alert('test')</script>"),
        isFalse,
      );
      expect(AuthService.isValidDisplayName('😂🔥'), isFalse);
    });

    test('rejects names longer than 50 characters', () {
      expect(
        AuthService.isValidDisplayName(List.filled(50, 'a').join()),
        isTrue,
      );
      expect(
        AuthService.isValidDisplayName(List.filled(51, 'a').join()),
        isFalse,
      );
    });
  });
}
