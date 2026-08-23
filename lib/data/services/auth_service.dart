import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get user => _auth.authStateChanges();

  Future<User?> registerWithEmail(String email, String password, String name) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = result.user;
    if (user == null) return null;

    await user.updateDisplayName(name.trim());

    // This must succeed: an email/password account is not considered ready
    // until Firebase has sent the verification message.
    await user.sendEmailVerification().timeout(const Duration(seconds: 20));

    unawaited(_syncUserProfile(user, nameOverride: name.trim(), isNew: true));
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
      unawaited(_syncUserProfile(refreshed!));
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
    await user.reload();
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
      final data = <String, dynamic>{
        'name': nameOverride ?? user.displayName,
        'email': user.email,
        'email_verified': user.emailVerified,
        'last_login': FieldValue.serverTimestamp(),
      };

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
