import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

const Duration profileNameChangeCooldown = Duration(days: 30);

DateTime? profileNameUpdatedAt(Map<String, dynamic>? data) {
  final value = data?['name_updated_at'];
  if (value is Timestamp) return value.toDate();
  return null;
}

Duration profileNameChangeRemaining(
  DateTime? lastChangedAt, {
  DateTime? now,
}) {
  if (lastChangedAt == null) return Duration.zero;
  final current = now ?? DateTime.now();
  final nextAllowedAt = lastChangedAt.add(profileNameChangeCooldown);
  if (!current.isBefore(nextAllowedAt)) return Duration.zero;
  return nextAllowedAt.difference(current);
}

String formatProfileNameCooldown(Duration remaining, {required bool isArabic}) {
  if (remaining <= Duration.zero) {
    return isArabic ? 'يمكن تغيير الاسم الآن' : 'Name can be changed now';
  }

  final days = remaining.inDays;
  final hours = remaining.inHours.remainder(24);
  final minutes = remaining.inMinutes.remainder(60);

  if (isArabic) {
    if (days > 0) return 'متبقي $days يوم و$hours ساعة';
    if (hours > 0) return 'متبقي $hours ساعة و$minutes دقيقة';
    return 'متبقي ${remaining.inMinutes.clamp(1, 59)} دقيقة';
  }

  if (days > 0) return '$days d $hours h remaining';
  if (hours > 0) return '$hours h $minutes min remaining';
  return '${remaining.inMinutes.clamp(1, 59)} min remaining';
}

String authProviderLabel(
  Iterable<String> providerIds, {
  required bool isArabic,
}) {
  final ids = providerIds.toSet();
  final labels = <String>[];

  if (ids.contains('google.com')) {
    labels.add('Google');
  }
  if (ids.contains('password')) {
    labels.add(isArabic ? 'البريد وكلمة المرور' : 'Email & password');
  }

  for (final id in ids) {
    if (id == 'google.com' || id == 'password') continue;
    if (id.trim().isNotEmpty) labels.add(id);
  }

  if (labels.isEmpty) {
    return isArabic ? 'غير معروف' : 'Unknown';
  }
  return labels.join(' + ');
}

class ProfileNameChangeException implements Exception {
  final String code;
  final Duration? remaining;

  const ProfileNameChangeException(this.code, {this.remaining});

  @override
  String toString() => code;
}

class ProfileService {
  final FirebaseFirestore _firestore;

  ProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> changeDisplayName({
    required User user,
    required String newName,
  }) async {
    final normalized = AuthService.normalizeDisplayName(newName);
    if (!AuthService.isValidDisplayName(normalized)) {
      throw const FormatException('invalid-display-name');
    }

    final ref = _firestore.collection('users').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final lastChangedAt = profileNameUpdatedAt(snapshot.data());
      final remaining = profileNameChangeRemaining(lastChangedAt);
      if (remaining > Duration.zero) {
        throw ProfileNameChangeException('name-change-cooldown', remaining: remaining);
      }

      transaction.set(
        ref,
        {
          'name': normalized,
          'name_updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    // Firestore is the canonical profile name. Firebase Auth is updated as a
    // best-effort mirror only, so an Auth-side failure cannot roll back a
    // securely accepted Firestore rename or overwrite it on the next login.
    try {
      await user.updateDisplayName(normalized);
      await user.reload();
    } catch (error) {
      debugPrint('Firebase Auth displayName mirror failed: $error');
    }
  }
}
