import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/auth_email_localization.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  static const int minDisplayNameLetters = 2;
  static const int maxDisplayNameLength = 50;
  static final RegExp _displayNamePattern = RegExp(
    r'^[A-Za-z\u0621-\u063A\u0641-\u064A ]+$',
  );
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String normalizeDisplayName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static bool isValidDisplayName(String value) {
    final normalized = normalizeDisplayName(value);
    final letterCount = normalized.replaceAll(' ', '').length;
    return letterCount >= minDisplayNameLetters &&
        normalized.length <= maxDisplayNameLength &&
        _displayNamePattern.hasMatch(normalized);
  }

  static String normalizeEmail(String value) => value.trim();

  static bool isValidEmail(String value) =>
      _emailPattern.hasMatch(normalizeEmail(value));

  static bool shouldRejectNewGoogleAccount({
    required bool isNewUser,
    required bool acceptedLegal,
  }) =>
      isNewUser && !acceptedLegal;

  Stream<User?> get user => _auth.authStateChanges();

  Future<User?> registerWithEmail(
    String email,
    String password,
    String name, {
    required bool acceptedLegal,
    required String emailLanguageCode,
  }) async {
    if (!acceptedLegal) {
      throw FirebaseAuthException(code: 'terms-consent-required');
    }

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

    // Keep Firebase's localized email template aligned with the language the
    // user is currently seeing in Munib. Only Arabic and English are supported
    // by the app today, so unknown locale variants safely fall back to English.
    await _auth.setLanguageCode(normalizeAuthEmailLanguage(emailLanguageCode));

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

  Future<void> sendPasswordResetEmail(
    String email, {
    required String languageCode,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    if (!isValidEmail(normalizedEmail)) {
      throw FirebaseAuthException(code: 'invalid-email');
    }

    try {
      await _auth.setLanguageCode(normalizeAuthEmailLanguage(languageCode));
      await _auth
          .sendPasswordResetEmail(email: normalizedEmail)
          .timeout(const Duration(seconds: 20));
    } on FirebaseAuthException catch (error) {
      // Keep the UI account-enumeration safe. Firebase may already suppress
      // this error when Email Enumeration Protection is enabled, but older or
      // differently configured projects can still report it.
      if (error.code == 'user-not-found') return;
      rethrow;
    }
  }

  Future<void> resendVerification({required String languageCode}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed != null && !refreshed.emailVerified) {
      await _auth.setLanguageCode(normalizeAuthEmailLanguage(languageCode));
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

  Future<User?> signInWithGoogle({required bool acceptedLegalForNewAccount}) async {
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
    if (user == null) return null;

    final isNewAccount = result.additionalUserInfo?.isNewUser == true;
    if (shouldRejectNewGoogleAccount(
      isNewUser: isNewAccount,
      acceptedLegal: acceptedLegalForNewAccount,
    )) {
      try {
        await user.delete().timeout(const Duration(seconds: 20));
      } finally {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
        await _auth.signOut();
      }
      throw FirebaseAuthException(code: 'terms-consent-required');
    }

    unawaited(_syncUserProfile(user));
    return user;
  }

  bool isPasswordUser(User user) =>
      user.providerData.any((provider) => provider.providerId == 'password');

  bool isGoogleUser(User user) =>
      user.providerData.any((provider) => provider.providerId == 'google.com');

  Future<void> changePassword({
    required User user,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!isPasswordUser(user)) {
      throw FirebaseAuthException(code: 'password-provider-required');
    }

    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(code: 'missing-email');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    // Password changes are security-sensitive. Always prove possession of the
    // current password immediately before updating it instead of relying only
    // on how recently the app session was created.
    await user
        .reauthenticateWithCredential(credential)
        .timeout(const Duration(seconds: 20));
    await user.updatePassword(newPassword).timeout(const Duration(seconds: 20));

    // Refresh the token after the credential change so subsequent authenticated
    // requests use fresh account state.
    await user.getIdToken(true);
  }

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
      final ref = _firestore.collection('users').doc(user.uid);
      final rawName = nameOverride ?? user.displayName;
      final normalizedName =
          rawName == null ? null : normalizeDisplayName(rawName);
      final data = <String, dynamic>{
        'email': user.email,
        'email_verified': user.emailVerified,
        'last_login': FieldValue.serverTimestamp(),
      };

      // Firestore becomes the canonical name once a valid profile name exists.
      // This prevents an older Firebase Auth displayName from overwriting a
      // user-approved rename during later sign-ins.
      var shouldWriteName = isNew;
      if (!isNew &&
          normalizedName != null &&
          isValidDisplayName(normalizedName)) {
        try {
          final existing = await ref.get().timeout(const Duration(seconds: 8));
          final savedName = existing.data()?['name'];
          shouldWriteName = !existing.exists ||
              savedName is! String ||
              !isValidDisplayName(savedName);
        } catch (_) {
          shouldWriteName = false;
        }
      }

      if (shouldWriteName &&
          normalizedName != null &&
          isValidDisplayName(normalizedName)) {
        data['name'] = normalizedName;
      }

      if (isNew) {
        data['created_at'] = FieldValue.serverTimestamp();
        data['score'] = 0;
      }

      await ref
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
