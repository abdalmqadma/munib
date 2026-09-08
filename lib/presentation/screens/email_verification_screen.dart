import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/services/email_verification_cooldown.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String uid;
  final bool initialMessageJustSent;
  final bool busy;
  final Future<void> Function() onCheckVerification;
  final Future<bool> Function() onResendVerification;
  final Future<void> Function() onLeaveVerification;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.uid,
    required this.initialMessageJustSent,
    required this.busy,
    required this.onCheckVerification,
    required this.onResendVerification,
    required this.onLeaveVerification,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _cooldownStore = EmailVerificationCooldownStore();
  Timer? _timer;
  Duration _remaining = Duration.zero;

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String t(String ar, String en) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _prepareCooldown();
  }

  @override
  void didUpdateWidget(covariant EmailVerificationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _prepareCooldown();
    }
  }

  Future<void> _prepareCooldown() async {
    _timer?.cancel();
    if (widget.initialMessageJustSent) {
      await _cooldownStore.markSent(widget.uid);
    }
    final remaining = await _cooldownStore.remaining(widget.uid);
    if (!mounted) return;
    setState(() => _remaining = remaining);
    _startTicker();
  }

  void _startTicker() {
    _timer?.cancel();
    if (_remaining <= Duration.zero) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final remaining = await _cooldownStore.remaining(widget.uid);
      if (!mounted) return;
      setState(() => _remaining = remaining);
      if (remaining <= Duration.zero) {
        _timer?.cancel();
      }
    });
  }

  Future<void> _resend() async {
    if (widget.busy || _remaining > Duration.zero) return;
    final sent = await widget.onResendVerification();
    if (!sent) return;
    await _cooldownStore.markSent(widget.uid);
    final remaining = await _cooldownStore.remaining(widget.uid);
    if (!mounted) return;
    setState(() => _remaining = remaining);
    _startTicker();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cooldownActive = _remaining > Duration.zero;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onLeaveVerification();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: widget.busy ? null : widget.onLeaveVerification,
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
                      t('تحقق من بريدك الإلكتروني', 'Verify your email'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t(
                        'أرسلنا رابط التفعيل إلى ${widget.email}. افتح الرسالة واضغط رابط التفعيل، ثم ارجع إلى منيب.',
                        'We sent a verification link to ${widget.email}. Open the email, use the verification link, then return to Munib.',
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t(
                        'إذا لم تجد الرسالة خلال دقائق، افحص مجلد الرسائل غير المرغوب فيها (Spam/Junk).',
                        'If you do not see the email after a few minutes, check Spam/Junk.',
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            widget.busy ? null : widget.onCheckVerification,
                        icon: const Icon(Icons.verified_rounded),
                        label: Text(
                          t('تحققت من بريدي', 'I verified my email'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            widget.busy || cooldownActive ? null : _resend,
                        icon: const Icon(Icons.outgoing_mail),
                        label: Text(
                          cooldownActive
                              ? t(
                                  'إعادة الإرسال خلال ${formatVerificationCooldown(_remaining)}',
                                  'Resend in ${formatVerificationCooldown(_remaining)}',
                                )
                              : t(
                                  'إعادة إرسال رسالة التفعيل',
                                  'Resend verification email',
                                ),
                        ),
                      ),
                    ),
                    if (widget.busy) ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(),
                    ],
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
