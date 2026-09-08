from pathlib import Path

path = Path('lib/presentation/screens/auth_screen.dart')
text = path.read_text()

old = "import '../../data/services/auth_service.dart';\nimport 'forgot_password_screen.dart';"
new = "import '../../data/services/auth_service.dart';\nimport 'email_verification_screen.dart';\nimport 'forgot_password_screen.dart';"
if text.count(old) != 1:
    raise SystemExit('import anchor mismatch')
text = text.replace(old, new, 1)

old = "  String verificationEmail = '';\n"
new = "  String verificationEmail = '';\n  String verificationUid = '';\n  bool verificationInitialMessageJustSent = false;\n"
if text.count(old) != 1:
    raise SystemExit('verification fields anchor mismatch')
text = text.replace(old, new, 1)

old = "      final email = _emailController.text.trim();\n      final password = _passwordController.text;\n      final user = isLogin\n"
new = "      final email = _emailController.text.trim();\n      final password = _passwordController.text;\n      final wasLogin = isLogin;\n      final user = isLogin\n"
if text.count(old) != 1:
    raise SystemExit('submit anchor mismatch')
text = text.replace(old, new, 1)

old = """        setState(() {
          verificationEmail = user.email ?? email;
          awaitingVerification = true;
        });
"""
new = """        setState(() {
          verificationEmail = user.email ?? email;
          verificationUid = user.uid;
          verificationInitialMessageJustSent = !wasLogin;
          awaitingVerification = true;
        });
"""
if text.count(old) != 1:
    raise SystemExit('unverified state anchor mismatch')
text = text.replace(old, new, 1)

start = text.index('  Future<void> _resendVerification() async {')
end = text.index('\n  Future<void> _leaveVerification() async {', start)
replacement = """  Future<bool> _resendVerification() async {
    if (isLoading) return false;
    setState(() => isLoading = true);
    var sent = false;
    try {
      await _auth.resendVerification();
      sent = true;
      if (mounted) _showMessage(context.tr('verificationResent'));
    } on FirebaseAuthException catch (e) {
      if (mounted) _showMessage(_authError(e.code));
    } catch (e) {
      if (mounted) _showMessage('${context.tr('authUnexpected')}\\n$e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
    return sent;
  }
"""
text = text[:start] + replacement + text[end:]

old = """    setState(() {
      awaitingVerification = false;
      isLogin = true;
      _passwordController.clear();
      _confirmController.clear();
    });
"""
new = """    setState(() {
      awaitingVerification = false;
      verificationUid = '';
      verificationInitialMessageJustSent = false;
      isLogin = true;
      _passwordController.clear();
      _confirmController.clear();
    });
"""
if text.count(old) != 1:
    raise SystemExit('leave anchor mismatch')
text = text.replace(old, new, 1)

start = text.index('    if (awaitingVerification) {')
end = text.index('\n\n    return Scaffold(', start)
replacement = """    if (awaitingVerification) {
      return EmailVerificationScreen(
        email: verificationEmail,
        uid: verificationUid,
        initialMessageJustSent: verificationInitialMessageJustSent,
        busy: isLoading,
        onCheckVerification: _checkVerification,
        onResendVerification: _resendVerification,
        onLeaveVerification: _leaveVerification,
      );
    }"""
text = text[:start] + replacement + text[end:]

path.write_text(text)
