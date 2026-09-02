import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  static const int minDisplayNameLetters = 2;
  static const int maxDisplayNameLength = 50;
  static final RegExp _displayNamePattern = RegExp(
    r'^[A-Za-z\u0621-\u063A\u0641-\u064A ]+$',
  );

  static String normalizeDisplayName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static bool isValidDisplayName(String value) {
    final normalized = normalizeDisplayName(value);
    final letterCount = normalized.replaceAll(' ', '').length;
    return letterCount >= minDisplayNameLetters &&
        normalized.length <= maxDisplayNameLength &&
        _displayNamePattern.hasMatch(normalized);
  }

  Stream<User?> get user => _auth.authStateChanges();

  Future<User?> registerWithEmail(String email, String password, String name) async {
    final normalizedName = normalizeDisplayName(name);
    if (!isValidDisplayName(normalizedName)) {
      throw const FormatException('invalid-display-name');
    }

    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = result.user;
    if (user == null) return null;

    await user.updateDisplayName(normalizedName);

    // This must succeed: an email/password account is not considered ready
    // until Firebase has sent the verification message.
    await user.sendEmailVerification().timeout(const Duration(seconds: 20));

    unawaited(_syncUserProfile(user, nameOverride: normalizedName, isNew: true));
    return user;
  }

  Future<User?> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = result.user;
    if (user != null) {
      await user.reload();
      final refreshed = _auth.currentUser;
      if (refreshed != null) unawaited(_syncUserProfile(refreshed));
      return refreshed;
    }
    return null;
  }

  Future<void> resendVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed != null && !refreshed.emailVerified) {
      await refreshed
          .sendEmailVerification()
          .timeout(const Duration(seconds: 20));
    }
  }

  Future<bool> refreshEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed?.emailVerified == true) {
      await refreshed!.getIdToken(true);
      unawaited(_syncUserProfile(refreshed));
      return true;
    }
    return false;
  }

  Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth
        .signInWithCredential(credential)
        .timeout(const Duration(seconds: 30));
    final user = result.user;
    if (user != null) {
      unawaited(_syncUserProfile(user));
    }
    return user;
  }

  bool isPasswordUser(User user) =>
      user.providerData.any((provider) => provider.providerId == 'password');

  Future<void> signOutUnverifiedPasswordUser() async {
    final user = _auth.currentUser;
    if (user == null || !isPasswordUser(user)) return;

    // Splash must never depend on the network being available. If Firebase
    // cannot refresh quickly, keep the cached session and let the app open.
    try {
      await user.reload().timeout(const Duration(seconds: 5));
    } catch (_) {
      return;
    }

    final refreshed = _auth.currentUser;
    if (refreshed != null && !refreshed.emailVerified) {
      await _auth.signOut();
    }
  }

  Future<void> _syncUserProfile(
    User user, {
    String? nameOverride,
    bool isNew = false,
  }) async {
    try {
      final rawName = nameOverride ?? user.displayName;
      final normalizedName =
          rawName == null ? null : normalizeDisplayName(rawName);
      final data = <String, dynamic>{
        'email': user.email,
        'email_verified': user.emailVerified,
        'last_login': FieldValue.serverTimestamp(),
      };
      if (normalizedName != null && isValidDisplayName(normalizedName)) {
        data['name'] = normalizedName;
      }

      if (isNew) {
        data['created_at'] = FieldValue.serverTimestamp();
        data['score'] = 0;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}
