import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/munib_theme.dart';
import '../../data/services/auth_service.dart';
import 'home_screen.dart';

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || isLoading) return;
    _formKey.currentState!.save();
    setState(() => isLoading = true);

    try {
      User? result;
      if (isLogin) {
        result = await _auth.signInWithEmail(email, password);
      } else {
        result = await _auth.registerWithEmail(email, password, name);
      }
      if (!mounted) return;
      if (result != null) {
        _goToHome();
        return;
      }
      _showError('تعذر إكمال العملية. تحقق من البيانات وحاول مجدداً.');
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final user = await _auth.signInWithGoogle();
      if (!mounted) return;
      if (user != null) {
        _goToHome();
      } else {
        _showError('تم إلغاء تسجيل الدخول أو تعذر الاتصال بجوجل.');
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, textAlign: TextAlign.right)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MunibTheme.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF143040), MunibTheme.background],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0x22D9A85A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0x55D9A85A)),
                    ),
                    child: const Icon(Icons.person_outline_rounded, color: MunibTheme.gold, size: 34),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    isLogin ? 'أهلاً بعودتك' : 'أنشئ حسابك في منيب',
                    style: const TextStyle(color: MunibTheme.textPrimary, fontSize: 27, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLogin ? 'سجّل الدخول لمزامنة ملفك الشخصي.' : 'سيستخدم منيب اسمك لتحية شخصية داخل التطبيق.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: MunibTheme.textSecondary, height: 1.6),
                  ),
                  const SizedBox(height: 34),
                  if (!isLogin) ...[
                    _field('الاسم الكامل', Icons.person_outline, (value) => name = value!),
                    const SizedBox(height: 14),
                  ],
                  _field('البريد الإلكتروني', Icons.mail_outline_rounded, (value) => email = value!, isEmail: true),
                  const SizedBox(height: 14),
                  _field('كلمة المرور', Icons.lock_outline_rounded, (value) => password = value!, isPass: true),
                  const SizedBox(height: 26),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: MunibTheme.gold),
                    )
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: Text(isLogin ? 'تسجيل الدخول' : 'إنشاء الحساب'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _signInWithGoogle,
                        icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                        label: const Text('المتابعة بواسطة جوجل'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: isLoading ? null : () => setState(() => isLogin = !isLogin),
                    child: Text(
                      isLogin ? 'ليس لديك حساب؟ إنشاء حساب' : 'لديك حساب؟ تسجيل الدخول',
                      style: const TextStyle(color: MunibTheme.goldSoft),
                    ),
                  ),
                  TextButton(
                    onPressed: isLoading ? null : () => Navigator.maybePop(context),
                    child: const Text('المتابعة بدون حساب', style: TextStyle(color: MunibTheme.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    IconData icon,
    FormFieldSetter<String> onSave, {
    bool isEmail = false,
    bool isPass = false,
  }) {
    return TextFormField(
      style: const TextStyle(color: MunibTheme.textPrimary),
      obscureText: isPass,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      textDirection: isEmail ? TextDirection.ltr : TextDirection.rtl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: MunibTheme.goldSoft, size: 20),
      ),
      validator: (value) => value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
      onSaved: onSave,
    );
  }
}
