import 'package:flutter_test/flutter_test.dart';
import 'package:munib/data/services/profile_service.dart';

void main() {
  group('profile name cooldown', () {
    final now = DateTime.utc(2026, 9, 8, 12);

    test('allows first manual name change when no timestamp exists', () {
      expect(
        profileNameChangeRemaining(null, now: now),
        Duration.zero,
      );
    });

    test('blocks name change before 30 days', () {
      final lastChangedAt = now.subtract(const Duration(days: 29, hours: 2));
      final remaining = profileNameChangeRemaining(
        lastChangedAt,
        now: now,
      );

      expect(remaining, const Duration(hours: 22));
    });

    test('allows name change exactly after 30 days', () {
      final lastChangedAt = now.subtract(const Duration(days: 30));
      expect(
        profileNameChangeRemaining(lastChangedAt, now: now),
        Duration.zero,
      );
    });

    test('allows name change after more than 30 days', () {
      final lastChangedAt = now.subtract(const Duration(days: 45));
      expect(
        profileNameChangeRemaining(lastChangedAt, now: now),
        Duration.zero,
      );
    });
  });

  group('auth provider label', () {
    test('shows Google provider', () {
      expect(
        authProviderLabel(const ['google.com'], isArabic: true),
        'Google',
      );
    });

    test('shows email/password provider in Arabic', () {
      expect(
        authProviderLabel(const ['password'], isArabic: true),
        'البريد وكلمة المرور',
      );
    });

    test('shows all linked providers', () {
      expect(
        authProviderLabel(
          const ['google.com', 'password'],
          isArabic: false,
        ),
        'Google + Email & password',
      );
    });
  });
}
