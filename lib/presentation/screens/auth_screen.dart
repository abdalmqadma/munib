import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/auth_service.dart';
import 'splash_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  bool isLogin = true;
  String email = '';
  String password = '';
  String name = '';
  bool isLoading = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    setState(() => isLoading = true);
    
    try {
      User? result;
      if (isLogin) {
        result = await _auth.signInWithEmail(email, password);
      } else {
        result = await _auth.registerWithEmail(email, password, name);
      }

      if (mounted) {
        if (result != null) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SplashScreen()));
        } else {
          _showError('تأكد من البيانات المحفوظة أو تفعيل حسابك');
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _signInWithGoogle() async {
    setState(() => isLoading = true);
    try {
      print("DEBUG: Starting Google Sign-In sequence...");
      final user = await _auth.signInWithGoogle();
      
      if (mounted) {
        if (user != null) {
          print("DEBUG: Google Sign-In Successful for user: ${user.email}");
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SplashScreen()));
        } else {
          print("DEBUG: Google Sign-In returned null (Cancelled or failed)");
          _showError('تم إلغاء عملية الدخول');
        }
      }
    } catch (e) {
      print("DEBUG: Fatal error during Google Sign-In: $e");
      _showError('حدث خطأ غير متوقع أثناء الاتصال بجوجل');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071019),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.lock_person_rounded, size: 80, color: Color(0xFFFFD166)),
                const SizedBox(height: 20),
                Text(
                  isLogin ? 'تسجيل الدخول' : 'إنشاء حساب جديد',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                if (!isLogin)
                  _buildTextField('الاسم الكامل', Icons.person, (val) => name = val!),
                const SizedBox(height: 20),
                _buildTextField('البريد الإلكتروني', Icons.email, (val) => email = val!, isEmail: true),
                const SizedBox(height: 20),
                _buildTextField('كلمة المرور', Icons.vpn_key, (val) => password = val!, isPass: true),
                const SizedBox(height: 40),
                if (isLoading)
                  const CircularProgressIndicator(color: Color(0xFFFFD166))
                else ...[
                  _buildPrimaryButton(),
                  const SizedBox(height: 20),
                  _buildGoogleButton(),
                ],
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin ? 'لا تملك حساباً؟ سجل الآن' : 'تملك حساباً بالفعل؟ سجل دخولك',
                    style: const TextStyle(color: Colors.white38),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, Function(String?) onSave, {bool isEmail = false, bool isPass = false}) {
    return TextFormField(
      style: const TextStyle(color: Colors.white),
      obscureText: isPass,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: const Color(0xFFFFD166), size: 20),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF1E88E5))),
      ),
      validator: (val) => val == null || val.isEmpty ? 'هذا الحقل مطلوب' : null,
      onSaved: onSave,
    );
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E88E5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(isLogin ? 'دخول' : 'إنشاء الحساب', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton.icon(
        onPressed: _signInWithGoogle,
        icon: const Icon(Icons.g_mobiledata_rounded, color: Colors.white, size: 32),
        label: const Text('الدخول بواسطة جوجل', style: TextStyle(color: Colors.white, fontSize: 16)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}
