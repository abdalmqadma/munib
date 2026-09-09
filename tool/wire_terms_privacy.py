from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if text.count(old) != 1:
        raise SystemExit(f'{label} anchor mismatch: {text.count(old)}')
    return text.replace(old, new, 1)


auth_path = Path('lib/presentation/screens/auth_screen.dart')
auth = auth_path.read_text()

auth = replace_once(
    auth,
    "import '../../core/app_strings.dart';\nimport '../../data/services/auth_service.dart';",
    "import '../../core/app_strings.dart';\nimport '../../core/legal_consent.dart';\nimport '../../data/services/auth_service.dart';",
    'auth legal import',
)
auth = replace_once(
    auth,
    "import 'home_screen.dart';",
    "import 'home_screen.dart';\nimport 'legal_document_screen.dart';",
    'auth screen import',
)
auth = replace_once(
    auth,
    "  bool verificationInitialMessageJustSent = false;\n",
    "  bool verificationInitialMessageJustSent = false;\n  bool acceptedLegal = false;\n",
    'consent field',
)
auth = replace_once(
    auth,
    "  Future<void> _submit() async {\n    if (isLoading || !_formKey.currentState!.validate()) return;\n    setState(() => isLoading = true);",
    "  Future<void> _submit() async {\n    if (isLoading || !_formKey.currentState!.validate()) return;\n    if (!canSubmitAuthAction(isLogin: isLogin, acceptedLegal: acceptedLegal)) {\n      _showMessage(\n        Localizations.localeOf(context).languageCode == 'ar'\n            ? 'يجب الموافقة على شروط الاستخدام وسياسة الخصوصية قبل إنشاء الحساب.'\n            : 'You must accept the Terms of Use and Privacy Policy before creating an account.',\n      );\n      return;\n    }\n    setState(() => isLoading = true);",
    'submit guard',
)
auth = replace_once(
    auth,
    "              _nameController.text.trim(),\n            );",
    "              _nameController.text.trim(),\n              acceptedLegal: acceptedLegal,\n            );",
    'email signup consent',
)
auth = replace_once(
    auth,
    "      final user = await _auth.signInWithGoogle();",
    "      final user = await _auth.signInWithGoogle(\n        acceptedLegalForNewAccount: acceptedLegal,\n      );",
    'google consent',
)
auth = replace_once(
    auth,
    "      case 'too-many-requests':\n        return context.tr('tooManyRequests');\n      default:",
    "      case 'too-many-requests':\n        return context.tr('tooManyRequests');\n      case 'terms-consent-required':\n        return Localizations.localeOf(context).languageCode == 'ar'\n            ? 'لإنشاء حساب جديد، انتقل إلى إنشاء حساب ووافق على شروط الاستخدام وسياسة الخصوصية.'\n            : 'To create a new account, switch to Create account and accept the Terms of Use and Privacy Policy.';\n      default:",
    'auth error',
)
auth = replace_once(
    auth,
    "      _passwordController.clear();\n      _confirmController.clear();\n    });\n  }",
    "      _passwordController.clear();\n      _confirmController.clear();\n      acceptedLegal = false;\n    });\n  }",
    'toggle reset',
)

consent_ui = r'''                    if (!isLogin) ...[
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: acceptedLegal,
                            onChanged: isLoading
                                ? null
                                : (value) => setState(
                                      () => acceptedLegal = value ?? false,
                                    ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    Localizations.localeOf(context).languageCode == 'ar'
                                        ? 'أوافق على '
                                        : 'I agree to the ',
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const LegalDocumentScreen(
                                          type: LegalDocumentType.terms,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      Localizations.localeOf(context).languageCode == 'ar'
                                          ? 'شروط الاستخدام'
                                          : 'Terms of Use',
                                    ),
                                  ),
                                  Text(
                                    Localizations.localeOf(context).languageCode == 'ar'
                                        ? ' و'
                                        : ' and the ',
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const LegalDocumentScreen(
                                          type: LegalDocumentType.privacy,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      Localizations.localeOf(context).languageCode == 'ar'
                                          ? 'سياسة الخصوصية'
                                          : 'Privacy Policy',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
'''
auth = replace_once(
    auth,
    "                    const SizedBox(height: 28),\n                    SizedBox(\n                      width: double.infinity,\n                      child: FilledButton(\n                        onPressed: isLoading ? null : _submit,",
    consent_ui + "                    const SizedBox(height: 28),\n                    SizedBox(\n                      width: double.infinity,\n                      child: FilledButton(\n                        onPressed: isLoading || (!isLogin && !acceptedLegal)\n                            ? null\n                            : _submit,",
    'consent UI and email button',
)
auth = replace_once(
    auth,
    "                      child: OutlinedButton.icon(\n                        onPressed: isLoading ? null : _signInWithGoogle,",
    "                      child: OutlinedButton.icon(\n                        onPressed: isLoading || (!isLogin && !acceptedLegal)\n                            ? null\n                            : _signInWithGoogle,",
    'google button gate',
)

auth_path.write_text(auth)

settings_path = Path('lib/presentation/screens/settings_screen.dart')
settings = settings_path.read_text()
settings = replace_once(
    settings,
    "import 'location_imsakia_screen.dart';",
    "import 'location_imsakia_screen.dart';\nimport 'legal_document_screen.dart';",
    'settings legal import',
)

legal_card = r'''                    const SizedBox(height: 24),
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          title: t('شروط الاستخدام', 'Terms of Use'),
                          subtitle: t(
                            'اقرأ شروط استخدام مُنِيب',
                            'Read the terms for using Munib',
                          ),
                          icon: Icons.description_outlined,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalDocumentScreen(
                                type: LegalDocumentType.terms,
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        _SettingsTile(
                          title: t('سياسة الخصوصية', 'Privacy Policy'),
                          subtitle: t(
                            'كيف يتعامل مُنِيب مع بياناتك',
                            'How Munib handles your data',
                          ),
                          icon: Icons.privacy_tip_outlined,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LegalDocumentScreen(
                                type: LegalDocumentType.privacy,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
'''
settings = replace_once(
    settings,
    "                    const SizedBox(height: 36),\n                    Text(\n                      context.tr('version'),",
    legal_card + "                    const SizedBox(height: 36),\n                    Text(\n                      context.tr('version'),",
    'settings legal card',
)
settings_path.write_text(settings)
