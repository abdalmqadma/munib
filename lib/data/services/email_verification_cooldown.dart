import 'package:shared_preferences/shared_preferences.dart';

const Duration emailVerificationResendCooldown = Duration(seconds: 60);

Duration emailVerificationCooldownRemaining({
  required int? lastSentAtMs,
  DateTime? now,
}) {
  if (lastSentAtMs == null) return Duration.zero;
  final current = now ?? DateTime.now();
  final expiresAt = DateTime.fromMillisecondsSinceEpoch(lastSentAtMs)
      .add(emailVerificationResendCooldown);
  final remaining = expiresAt.difference(current);
  return remaining.isNegative ? Duration.zero : remaining;
}

String formatVerificationCooldown(Duration remaining) {
  if (remaining <= Duration.zero) return '00:00';
  final totalSeconds = (remaining.inMilliseconds / 1000).ceil();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

class EmailVerificationCooldownStore {
  static const String _keyPrefix = 'email_verification_last_sent_';

  String _key(String uid) => '$_keyPrefix$uid';

  Future<void> markSent(String uid, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _key(uid),
      (now ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  Future<Duration> remaining(String uid, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    return emailVerificationCooldownRemaining(
      lastSentAtMs: prefs.getInt(_key(uid)),
      now: now,
    );
  }

  Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
  }
}
