import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get user => _auth.authStateChanges();

  Future<User?> registerWithEmail(String email, String password, String name) async {
    final result = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = result.user;
    if (user != null) {
      await user.updateDisplayName(name.trim());
      await _firestore.collection('users').doc(user.uid).set({
        'name': name.trim(), 'email': email.trim(), 'created_at': FieldValue.serverTimestamp(),
        'score': 0, 'email_verified': false,
      }, SetOptions(merge: true));
      await user.sendEmailVerification();
    }
    return user;
  }

  Future<User?> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    return result.user;
  }

  Future<void> resendVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) await user.sendEmailVerification();
  }

  Future<bool> refreshEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed?.emailVerified == true) {
      await _firestore.collection('users').doc(refreshed!.uid).set({
        'email_verified': true, 'last_login': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    }
    return false;
  }

  Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'name': user.displayName, 'email': user.email, 'email_verified': user.emailVerified,
        'last_login': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return user;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
