import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_strings.dart';
import '../../data/services/auth_service.dart';
import 'splash_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool returnOnSuccess;

  const AuthScreen({super.key, this.returnOnSuccess = false});

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

  Future<void> _finishAuth(User user) async {
    if (!mounted) return;
    if (widget.returnOnSuccess) {
      Navigator.pop(context, true);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  Future<void> _submit() async {
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

      if (!mounted) return;
      if (result != null) {
        await _finishAuth(result);
      } else {
        _showError(context.tr('invalidCredentials'));
      }
    } catch (_) {
      if (mounted) _showError(context.tr('invalidCredentials'));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => isLoading = true);
    try {
      final user = await _auth.signInWithGoogle();
      if (!mounted) return;

      if (user != null) {
        await _finishAuth(user);
      } else {
        _showError(context.tr('googleCancelled'));
      }
    } catch (_) {
      if (mounted) _showError(context.tr('googleError'));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: widget.returnOnSuccess ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Icon(Icons.lock_person_rounded, size: 46, color: scheme.primary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isLogin ? context.tr('signIn') : context.tr('createAccount'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 34),
                    if (!isLogin) ...[
                      _field(
                        label: context.tr('fullName'),
                        icon: Icons.person_outline_rounded,
                        onSave: (value) => name = value!,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _field(
                      label: context.tr('email'),
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      onSave: (value) => email = value!,
                    ),
                    const SizedBox(height: 16),
                    _field(
                      label: context.tr('password'),
                      icon: Icons.key_rounded,
                      obscureText: true,
                      onSave: (value) => password = value!,
                    ),
                    const SizedBox(height: 28),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(),
                      )
                    else ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submit,
                          child: Text(isLogin ? context.tr('login') : context.tr('register')),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _signInWithGoogle,
                          icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                          label: Text(context.tr('googleLogin')),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => isLogin = !isLogin),
                      child: Text(isLogin ? context.tr('noAccount') : context.tr('haveAccount')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required IconData icon,
    required FormFieldSetter<String> onSave,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return Builder(
      builder: (context) => TextFormField(
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? context.tr('requiredField')
            : null,
        onSaved: onSave,
      ),
    );
  }
}
