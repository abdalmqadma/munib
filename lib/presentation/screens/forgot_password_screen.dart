import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  late final TextEditingController _emailController;

  bool _busy = false;
  bool _sent = false;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String t(String ar, String en) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _formKey.currentState?.validate() != true) return;

    setState(() => _busy = true);
    try {
      await _auth.sendPasswordResetEmail(_emailController.text);
      if (!mounted) return;
      setState(() => _sent = true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'invalid-email' => t(
            'تأكد من كتابة البريد الإلكتروني بشكل صحيح.',
            'Enter a valid email address.',
          ),
        'too-many-requests' => t(
            'تم إرسال طلبات كثيرة. حاول مرة أخرى لاحقًا.',
            'Too many requests. Try again later.',
          ),
        'network-request-failed' => t(
            'تحقق من اتصال الإنترنت وحاول مرة أخرى.',
            'Check your internet connection and try again.',
          ),
        _ => t(
            'تعذر إرسال رسالة إعادة التعيين. حاول مرة أخرى.',
            'Could not send the reset email. Try again.',
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
              'تعذر إرسال رسالة إعادة التعيين. حاول مرة أخرى.',
              'Could not send the reset email. Try again.',
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('نسيت كلمة المرور', 'Forgot password')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _sent ? _successContent(theme, scheme) : _formContent(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formContent(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.mark_email_unread_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            t('استعادة كلمة المرور', 'Reset your password'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            t(
              'اكتب البريد المرتبط بحسابك في منيب وسنرسل لك رابط إعادة تعيين كلمة المرور.',
              'Enter the email linked to your Munib account and we will send you a password reset link.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _send(),
            decoration: InputDecoration(
              labelText: t('البريد الإلكتروني', 'Email'),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (value) => AuthService.isValidEmail(value ?? '')
                ? null
                : t('اكتب بريدًا إلكترونيًا صحيحًا.', 'Enter a valid email.'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _send,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.outgoing_mail_rounded),
            label: Text(t('إرسال رابط إعادة التعيين', 'Send reset link')),
          ),
        ],
      ),
    );
  }

  Widget _successContent(ThemeData theme, ColorScheme scheme) {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Icon(
            Icons.mark_email_read_outlined,
            size: 44,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          t('تحقق من بريدك', 'Check your email'),
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          t(
            'إذا كان هذا البريد مربوطًا بحساب في منيب، ستصلك رسالة لإعادة تعيين كلمة المرور.',
            'If this email is linked to a Munib account, you will receive a password reset email.',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          t(
            'إذا لم تجد الرسالة خلال دقائق، افحص مجلد الرسائل غير المرغوب فيها (Spam/Junk).',
            'If you do not see the email after a few minutes, check Spam/Junk.',
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () {
                    setState(() => _sent = false);
                  },
            icon: const Icon(Icons.refresh_rounded),
            label: Text(t('إرسال مرة أخرى', 'Send again')),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('العودة لتسجيل الدخول', 'Back to sign in')),
        ),
      ],
    );
  }
}
