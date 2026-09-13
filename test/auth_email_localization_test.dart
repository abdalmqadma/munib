import 'package:flutter_test/flutter_test.dart';
import 'package:munib/core/auth_email_localization.dart';

void main() {
  group('normalizeAuthEmailLanguage', () {
    test('keeps Arabic locale variants Arabic', () {
      expect(normalizeAuthEmailLanguage('ar'), 'ar');
      expect(normalizeAuthEmailLanguage('ar-PS'), 'ar');
      expect(normalizeAuthEmailLanguage(' AR '), 'ar');
    });

    test('keeps English and unknown locales on safe English fallback', () {
      expect(normalizeAuthEmailLanguage('en'), 'en');
      expect(normalizeAuthEmailLanguage('en-US'), 'en');
      expect(normalizeAuthEmailLanguage('fr'), 'en');
      expect(normalizeAuthEmailLanguage(''), 'en');
    });
  });
}
