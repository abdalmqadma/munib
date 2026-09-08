import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/services/auth_service.dart';
import '../../data/services/password_change_validation.dart';

class ChangePasswordScreen extends StatefulWidget {
  final User user;

  const ChangePasswordScreen({super.key, required this.user});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _auth = AuthService();

  bool _busy = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String t(String ar, String en) => _isArabic ? ar : en;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _fieldError(String field) {
    final code = validatePasswordChange(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
      confirmation: _confirmController.text,
    );

    if (field == 'current' && code == 'current-required') {
      return t('أدخل كلمة المرور الحالية.', 'Enter your current password.');
    }
    if (field == 'new' && code == 'new-too-short') {
      return t(
        'كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل.',
        'The new password must be at least 6 characters.',
      );
    }
    if (field == 'new' && code == 'same-password') {
      return t(
        'اختر كلمة مرور مختلفة عن الحالية.',
        'Choose a password different from the current one.',
      );
    }
    if (field == 'confirm' && code == 'confirmation-mismatch') {
      return t('كلمتا المرور غير متطابقتين.', 'Passwords do not match.');
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy || _formKey.currentState?.validate() != true) return;

    final validation = validatePasswordChange(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
      confirmation: _confirmController.text,
    );
    if (validation != null) return;

    setState(() => _busy = true);
    try {
      await _auth.changePassword(
        user: widget.user,
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'wrong-password' || 'invalid-credential' => t(
            'كلمة المرور الحالية غير صحيحة.',
            'The current password is incorrect.',
          ),
        'weak-password' => t(
            'كلمة المرور الجديدة ضعيفة. اختر كلمة مرور أقوى.',
            'The new password is too weak. Choose a stronger password.',
          ),
        'too-many-requests' => t(
            'محاولات كثيرة. حاول مرة أخرى لاحقًا.',
            'Too many attempts. Try again later.',
          ),
        'network-request-failed' => t(
            'تحقق من اتصال الإنترنت وحاول مرة أخرى.',
            'Check your internet connection and try again.',
          ),
        'requires-recent-login' => t(
            'تعذر تأكيد الجلسة. سجل الدخول من جديد ثم حاول مرة أخرى.',
            'Could not confirm the session. Sign in again and retry.',
          ),
        'password-provider-required' => t(
            'هذا الحساب لا يستخدم كلمة مرور داخل منيب.',
            'This account does not use a password in Munib.',
          ),
        _ => t(
            'تعذر تغيير كلمة المرور. حاول مرة أخرى.',
            'Could not change the password. Try again.',
          ),
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'تعذر تغيير كلمة المرور. حاول مرة أخرى.',
              'Could not change the password. Try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('تغيير كلمة المرور', 'Change password'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              t(
                'لأمان حسابك، أدخل كلمة المرور الحالية قبل تعيين كلمة مرور جديدة.',
                'For account security, enter your current password before setting a new one.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _currentController,
                    obscureText: !_showCurrent,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: t('كلمة المرور الحالية', 'Current password'),
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _showCurrent = !_showCurrent),
                        icon: Icon(
                          _showCurrent
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (_) => _fieldError('current'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newController,
                    obscureText: !_showNew,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: t('كلمة المرور الجديدة', 'New password'),
                      prefixIcon: const Icon(Icons.password_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _showNew = !_showNew),
                        icon: Icon(
                          _showNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (_) => _fieldError('new'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: !_showConfirm,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: t('تأكيد كلمة المرور الجديدة', 'Confirm new password'),
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _showConfirm = !_showConfirm),
                        icon: Icon(
                          _showConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (_) => _fieldError('confirm'),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_reset_rounded),
              label: Text(t('حفظ كلمة المرور الجديدة', 'Save new password')),
            ),
          ],
        ),
      ),
    );
  }
}
