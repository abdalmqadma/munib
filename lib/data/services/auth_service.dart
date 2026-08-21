import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get user => _auth.authStateChanges();

  Future<User?> registerWithEmail(String email, String password, String name) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;

      if (user != null) {
        final trimmedName = name.trim();
        if (trimmedName.isNotEmpty) {
          await user.updateDisplayName(trimmedName);
          await user.reload();
        }

        unawaited(
          _firestore.collection('users').doc(user.uid).set({
            'name': trimmedName,
            'email': email,
            'created_at': FieldValue.serverTimestamp(),
            'score': 0,
          }, SetOptions(merge: true)).timeout(const Duration(seconds: 8)).catchError((_) {}),
        );

        return FirebaseAuth.instance.currentUser;
      }

      return null;
    } on FirebaseAuthException {
      return null;
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 15));
      return result.user;
    } on FirebaseAuthException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 15));
      final user = result.user;

      if (user != null) {
        unawaited(
          _firestore.collection('users').doc(user.uid).set({
            'name': user.displayName,
            'email': user.email,
            'last_login': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)).timeout(const Duration(seconds: 8)).catchError((_) {}),
        );
      }

      return user;
    } on FirebaseAuthException {
      return null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
