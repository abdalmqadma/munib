import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // مراقبة حالة المستخدم
  Stream<User?> get user => _auth.authStateChanges();

  // تسجيل مستخدم جديد بالبريد
  Future<User?> registerWithEmail(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      User? user = result.user;
      
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'created_at': FieldValue.serverTimestamp(),
          'score': 0,
        });
      }
      return user;
    } catch (e) {
      return null;
    }
  }

  // تسجيل الدخول بالبريد
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } catch (e) {
      return null;
    }
  }

  // تسجيل الدخول بواسطة جوجل
  Future<User?> signInWithGoogle() async {
    try {
      // 1. بدء عملية الدخول
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("DEBUG: Google User is null (User cancelled)");
        return null;
      }

      // 2. الحصول على بيانات المصادقة
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // 3. إنشاء اعتماد Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. تسجيل الدخول في Firebase
      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': user.displayName,
          'email': user.email,
          'last_login': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return user;
    } catch (e) {
      print("DEBUG: Google Login Error Detailed: $e");
      return null;
    }
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
