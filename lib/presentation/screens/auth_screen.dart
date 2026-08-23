import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  bool obscurePassword = true;
  bool awaitingVerification = false;
  String verificationEmail = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
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
    if (isLoading || !_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final user = isLogin
          ? await _auth.signInWithEmail(email, password)
          : await _auth.registerWithEmail(
              email,
              password,
              _nameController.text.trim(),
            );

      if (!mounted || user == null) return;

      if (_auth.isPasswordUser(user) && !user.emailVerified) {
        setState(() {
          verificationEmail = user.email ?? email;
          awaitingVerification = true;
        });
        return;
      }

      await _finishAuth(user);
    } on FirebaseAuthException catch (e) {
      if (mounted) _showMessage(_authError(e.code));
    } catch (e) {
      if (mounted) _showMessage('${context.tr('authUnexpected')}\n$e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _checkVerification() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final verified = await _auth.refreshEmailVerification();
      if (!mounted) return;
      if (!verified) {
        _showMessage(context.tr('emailNotVerifiedYet'));
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) await _finishAuth(user);
    } on FirebaseAuthException catch (e) {
      if (mounted) _showMessage(_authError(e.code));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _resendVerification() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      await _auth.resendVerification();
      if (mounted) _showMessage(context.tr('verificationResent'));
    } on FirebaseAuthException catch (e) {
      if (mounted) _showMessage(_authError(e.code));
    } catch (e) {
      if (mounted) _showMessage('${context.tr('authUnexpected')}\n$e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _leaveVerification() async {
    await _auth.signOut();
    if (!mounted) return;
    setState(() {
      awaitingVerification = false;
      isLogin = true;
      _passwordController.clear();
      _confirmController.clear();
    });
  }

  Future<void> _signInWithGoogle() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      final user = await _auth.signInWithGoogle();
      if (!mounted) return;
      if (user == null) {
        _showMessage(context.tr('googleCancelled'));
        return;
      }
      await _finishAuth(user);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final code = e.code.toLowerCase();
      if (code.contains('sign_in_failed') || code.contains('10')) {
        _showMessage(
          'Google Sign-In configuration error. Check the release SHA-1/SHA-256 in Firebase.',
        );
      } else if (code.contains('network')) {
        _showMessage(context.tr('googleError'));
      } else {
        _showMessage('${context.tr('googleError')} (${e.code})');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showMessage(_authError(e.code));
    } catch (e) {
      if (mounted) _showMessage('${context.tr('googleError')}\n$e');
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _toggleMode() {
    if (isLoading) return;
    setState(() {
      isLogin = !isLogin;
      _formKey.currentState?.reset();
      _passwordController.clear();
      _confirmController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (awaitingVerification) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: isLoading ? null : _leaveVerification,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
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
                      context
                          .tr('verifyEmailBody')
                          .replaceAll('{email}', verificationEmail),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isLoading ? null : _checkVerification,
                        icon: const Icon(Icons.verified_rounded),
                        label: Text(context.tr('iveVerified')),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : _resendVerification,
                        icon: const Icon(Icons.outgoing_mail),
                        label: Text(context.tr('resendVerification')),
                      ),
                    ),
                    if (isLoading) ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(),
                    ],
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
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Icon(
                        Icons.lock_person_rounded,
                        size: 44,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      isLogin ? context.tr('signIn') : context.tr('createAccount'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 30),
                    if (!isLogin) ...[
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: context.tr('fullName'),
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => (v?.trim().length ?? 0) < 2
                            ? context.tr('nameTooShort')
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: context.tr('email'),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(v?.trim() ?? '')
                          ? null
                          : context.tr('invalidEmail'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: obscurePassword,
                      textInputAction: isLogin
                          ? TextInputAction.done
                          : TextInputAction.next,
                      onFieldSubmitted: isLogin ? (_) => _submit() : null,
                      decoration: InputDecoration(
                        labelText: context.tr('password'),
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => obscurePassword = !obscurePassword,
                          ),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
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
                    ),
                    if (!isLogin) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: context.tr('confirmPassword'),
                          prefixIcon: const Icon(Icons.key_outlined),
                        ),
                        validator: (v) => v != _passwordController.text
                            ? context.tr('passwordsDontMatch')
                            : null,
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : Text(
                                isLogin
                                    ? context.tr('login')
                                    : context.tr('register'),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : _signInWithGoogle,
                        icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                        label: Text(context.tr('googleLogin')),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _toggleMode,
                      child: Text(
                        isLogin
                            ? context.tr('noAccount')
                            : context.tr('haveAccount'),
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
}
