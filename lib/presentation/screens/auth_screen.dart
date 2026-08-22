import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_strings.dart';
import '../../data/services/auth_service.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool returnOnSuccess;
  const AuthScreen({super.key, this.returnOnSuccess = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  bool awaitingVerification = false;
  bool obscurePassword = true;
  String email = '';
  String password = '';
  String name = '';

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _finishAuth(User user) async {
    if (!mounted) return;

    if (widget.returnOnSuccess) {
      Navigator.pop(context, true);
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => isLoading = true);
    try {
      final result = isLogin
          ? await _auth.signInWithEmail(email, password)
          : await _auth.registerWithEmail(email, password, name);

      if (!mounted || result == null) return;

      if (!result.emailVerified) {
        setState(() => awaitingVerification = true);
        return;
      }

      await _finishAuth(result);
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_authError(e.code));
    } catch (_) {
      if (mounted) _showError(context.tr('authUnexpected'));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return context.tr('emailAlreadyUsed');
      case 'weak-password':
        return context.tr('weakPassword');
      case 'invalid-email':
        return context.tr('invalidEmail');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return context.tr('invalidCredentials');
      case 'too-many-requests':
        return context.tr('tooManyRequests');
      default:
        return context.tr('authUnexpected');
    }
  }

  Future<void> _checkVerification() async {
    setState(() => isLoading = true);
    try {
      if (await _auth.refreshEmailVerification()) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) await _finishAuth(user);
      } else if (mounted) {
        _showError(context.tr('emailNotVerifiedYet'));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await _auth.resendVerification();
      if (mounted) _showError(context.tr('verificationResent'));
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_authError(e.code));
    }
  }

  Future<void> _signInWithGoogle() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      final user = await _auth.signInWithGoogle();
      if (!mounted) return;

      if (user == null) {
        _showError(context.tr('googleCancelled'));
        return;
      }

      await _finishAuth(user);
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_authError(e.code));
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

    if (awaitingVerification) {
      return Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Icon(
                        Icons.mark_email_read_outlined,
                        size: 46,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      context.tr('verifyEmailTitle'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('verifyEmailBody').replaceAll('{email}', email),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isLoading ? null : _checkVerification,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(context.tr('iveVerified')),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: isLoading ? null : _resend,
                      child: Text(context.tr('resendVerification')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

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
                      child: Icon(
                        Icons.lock_person_rounded,
                        size: 46,
                        color: scheme.primary,
                      ),
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
                        validator: (v) => (v?.trim().length ?? 0) < 2
                            ? context.tr('nameTooShort')
                            : null,
                        onSave: (v) => name = v!.trim(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _field(
                      label: context.tr('email'),
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(v?.trim() ?? '')
                          ? null
                          : context.tr('invalidEmail'),
                      onSave: (v) => email = v!.trim(),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      controller: _passwordController,
                      label: context.tr('password'),
                      icon: Icons.key_rounded,
                      obscureText: obscurePassword,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => obscurePassword = !obscurePassword),
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      validator: (v) {
                        if (isLogin) {
                          return (v?.isEmpty ?? true)
                              ? context.tr('requiredField')
                              : null;
                        }
                        if ((v?.length ?? 0) < 8) {
                          return context.tr('passwordMin8');
                        }
                        if (!RegExp(r'[A-Za-z]').hasMatch(v ?? '') ||
                            !RegExp(r'\d').hasMatch(v ?? '')) {
                          return context.tr('passwordLetterNumber');
                        }
                        return null;
                      },
                      onSave: (v) => password = v!,
                    ),
                    if (!isLogin) ...[
                      const SizedBox(height: 16),
                      _field(
                        controller: _confirmController,
                        label: context.tr('confirmPassword'),
                        icon: Icons.key_outlined,
                        obscureText: obscurePassword,
                        validator: (v) => v != _passwordController.text
                            ? context.tr('passwordsDontMatch')
                            : null,
                        onSave: (_) {},
                      ),
                    ],
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
                          child: Text(
                            isLogin ? context.tr('login') : context.tr('register'),
                          ),
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
                      onPressed: isLoading
                          ? null
                          : () => setState(() {
                                isLogin = !isLogin;
                                _formKey.currentState?.reset();
                                _passwordController.clear();
                                _confirmController.clear();
                              }),
                      child: Text(
                        isLogin ? context.tr('noAccount') : context.tr('haveAccount'),
                      ),
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
    TextEditingController? controller,
    required String label,
    required IconData icon,
    required FormFieldSetter<String> onSave,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
      validator: validator ??
          (v) => v == null || v.trim().isEmpty
              ? context.tr('requiredField')
              : null,
      onSaved: onSave,
    );
  }
}
