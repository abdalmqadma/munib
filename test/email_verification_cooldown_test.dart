import 'package:flutter_test/flutter_test.dart';
import 'package:munib/data/services/email_verification_cooldown.dart';

void main() {
  group('emailVerificationCooldownRemaining', () {
    final now = DateTime(2026, 9, 8, 12);

    test('returns zero when no message was recorded', () {
      expect(
        emailVerificationCooldownRemaining(
          lastSentAtMs: null,
          now: now,
        ),
        Duration.zero,
      );
    });

    test('returns remaining time inside 60 second cooldown', () {
      final sentAt = now.subtract(const Duration(seconds: 25));
      expect(
        emailVerificationCooldownRemaining(
          lastSentAtMs: sentAt.millisecondsSinceEpoch,
          now: now,
        ),
        const Duration(seconds: 35),
      );
    });

    test('returns zero after cooldown expires', () {
      final sentAt = now.subtract(const Duration(seconds: 61));
      expect(
        emailVerificationCooldownRemaining(
          lastSentAtMs: sentAt.millisecondsSinceEpoch,
          now: now,
        ),
        Duration.zero,
      );
    });
  });

  test('formats countdown as mm:ss and rounds up partial seconds', () {
    expect(formatVerificationCooldown(const Duration(seconds: 7)), '00:07');
    expect(
      formatVerificationCooldown(const Duration(milliseconds: 59501)),
      '01:00',
    );
  });
}
