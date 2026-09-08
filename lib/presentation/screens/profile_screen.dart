import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_strings.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/profile_photo_service.dart';
import '../../data/services/profile_service.dart';
import 'auth_screen.dart';
import 'change_password_screen.dart';
import 'home_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool photoBusy = false;
  bool nameBusy = false;
  bool _clearingUnverifiedSession = false;
  Timer? _cooldownTicker;
  final _profilePhotoService = ProfilePhotoService();
  final _profileService = ProfileService();
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _cooldownTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    super.dispose();
  }

  void _clearUnverifiedSession() {
    if (_clearingUnverifiedSession) return;
    _clearingUnverifiedSession = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _auth.signOut();
      } finally {
        if (mounted) {
          setState(() => _clearingUnverifiedSession = false);
        }
      }
    });
  }

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  String t(String ar, String en) => _isArabic ? ar : en;

  Future<void> changePhoto(User user) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (picked == null || !mounted) return;

    setState(() => photoBusy = true);
    try {
      final url = await _profilePhotoService.upload(
        user: user,
        bytes: await picked.readAsBytes(),
      );
      await user.updatePhotoURL(url);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'photo_url': url,
          'photo_public_id': 'munib/profile_images/${user.uid}',
          'photo_updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await user.reload();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'تعذر رفع الصورة. حاول مرة أخرى.',
                'Could not upload the photo. Try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => photoBusy = false);
    }
  }

  Future<void> _changeName({
    required User user,
    required String currentName,
    required DateTime? lastChangedAt,
  }) async {
    final remaining = profileNameChangeRemaining(lastChangedAt);
    if (remaining > Duration.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            formatProfileNameCooldown(remaining, isArabic: _isArabic),
          ),
        ),
      );
      return;
    }

    final controller = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('تغيير الاسم', 'Change name')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: AuthService.maxDisplayNameLength,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: t('الاسم', 'Name'),
              helperText: t(
                'يمكن تغيير الاسم مرة واحدة كل 30 يومًا.',
                'You can change your name once every 30 days.',
              ),
            ),
            validator: (value) {
              if (!AuthService.isValidDisplayName(value ?? '')) {
                return t(
                  'اكتب اسمًا صحيحًا بالحروف فقط.',
                  'Enter a valid name using letters only.',
                );
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(dialogContext).pop(
                  AuthService.normalizeDisplayName(controller.text),
                );
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.of(dialogContext).pop(
                AuthService.normalizeDisplayName(controller.text),
              );
            },
            child: Text(t('حفظ', 'Save')),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null || !mounted) return;
    if (AuthService.normalizeDisplayName(newName) ==
        AuthService.normalizeDisplayName(currentName)) {
      return;
    }

    setState(() => nameBusy = true);
    try {
      await _profileService.changeDisplayName(user: user, newName: newName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تم تغيير الاسم.', 'Name updated.')),
        ),
      );
    } on ProfileNameChangeException catch (error) {
      if (!mounted) return;
      final cooldown = error.remaining ?? profileNameChangeCooldown;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'name-change-cooldown'
                ? formatProfileNameCooldown(cooldown, isArabic: _isArabic)
                : t('تعذر تغيير الاسم.', 'Could not update the name.'),
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'permission-denied'
                ? t(
                    'لا يمكن تغيير الاسم قبل مرور 30 يومًا من آخر تغيير.',
                    'The name cannot be changed until 30 days after the last change.',
                  )
                : t('تعذر تغيير الاسم.', 'Could not update the name.'),
          ),
        ),
      );
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'الاسم غير صالح. استخدم الحروف والمسافات فقط.',
              'Invalid name. Use letters and spaces only.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تعذر تغيير الاسم.', 'Could not update the name.')),
        ),
      );
    } finally {
      if (mounted) setState(() => nameBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final scheme = Theme.of(context).colorScheme;
    final hasUnverifiedPasswordSession = currentUser != null &&
        _auth.isPasswordUser(currentUser) &&
        !currentUser.emailVerified;

    if (hasUnverifiedPasswordSession) {
      _clearUnverifiedSession();
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('profile'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('profile'))),
        body: Center(
          child: FilledButton.icon(
            onPressed: () async {
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const AuthScreen(returnOnSuccess: true),
                ),
              );
              if (ok == true && context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              }
            },
            icon: const Icon(Icons.login_rounded),
            label: Text(context.tr('signIn')),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile'))),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final savedName = data?['name'] as String?;
            final authName = user.displayName;
            final hasSavedName = AuthService.isValidDisplayName(savedName ?? '');
            final hasAuthName = AuthService.isValidDisplayName(authName ?? '');
            final name = hasSavedName
                ? AuthService.normalizeDisplayName(savedName!)
                : (hasAuthName
                    ? AuthService.normalizeDisplayName(authName!)
                    : context.tr('munibUser'));
            final editableName = hasSavedName
                ? AuthService.normalizeDisplayName(savedName!)
                : (hasAuthName ? AuthService.normalizeDisplayName(authName!) : '');
            final email = user.email ?? (data?['email'] as String?) ?? '';
            final savedPhoto = data?['photo_url'] as String?;
            final photo = savedPhoto?.trim().isNotEmpty == true
                ? savedPhoto
                : user.photoURL;
            final lastNameChange = profileNameUpdatedAt(data);
            final nameCooldown = profileNameChangeRemaining(lastNameChange);
            final canChangeName = nameCooldown <= Duration.zero;
            final provider = authProviderLabel(
              user.providerData.map((item) => item.providerId),
              isArabic: _isArabic,
            );
            final hasPasswordProvider = _auth.isPasswordUser(user);
            final isGoogleOnly =
                !hasPasswordProvider && _auth.isGoogleUser(user);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 30,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: scheme.outline),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: scheme.primaryContainer,
                            foregroundImage: (photo ?? '').isNotEmpty
                                ? NetworkImage(photo!)
                                : null,
                            child: (photo ?? '').isEmpty
                                ? Icon(
                                    Icons.person_rounded,
                                    size: 48,
                                    color: scheme.primary,
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: IconButton.filled(
                              onPressed:
                                  photoBusy ? null : () => changePhoto(user),
                              icon: photoBusy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 18,
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          email,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: photoBusy ? null : () => changePhoto(user),
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: Text(
                          t(
                            'تغيير صورة الملف الشخصي',
                            'Change profile photo',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _InfoTile(
                  icon: Icons.badge_outlined,
                  title: t('الاسم', 'Name'),
                  value: name,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: nameBusy || !canChangeName
                      ? null
                      : () => _changeName(
                            user: user,
                            currentName: editableName,
                            lastChangedAt: lastNameChange,
                          ),
                  icon: nameBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit_note_rounded),
                  label: Text(t('تغيير الاسم', 'Change name')),
                ),
                const SizedBox(height: 6),
                Text(
                  formatProfileNameCooldown(
                    nameCooldown,
                    isArabic: _isArabic,
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: canChangeName
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 18),
                _InfoTile(
                  icon: Icons.email_outlined,
                  title: context.tr('email'),
                  value: email.isEmpty ? context.tr('notAvailable') : email,
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: Icons.login_rounded,
                  title: t('طريقة تسجيل الدخول', 'Sign-in method'),
                  value: provider,
                ),
                const SizedBox(height: 12),
                if (hasPasswordProvider)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangePasswordScreen(user: user),
                        ),
                      );
                      if (changed == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              t(
                                'تم تغيير كلمة المرور بنجاح.',
                                'Password changed successfully.',
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.lock_reset_rounded),
                    label: Text(
                      t('تغيير كلمة المرور', 'Change password'),
                    ),
                  )
                else if (isGoogleOnly)
                  _InfoTile(
                    icon: Icons.lock_outline_rounded,
                    title: t('كلمة المرور', 'Password'),
                    value: t(
                      'تُدار كلمة المرور بواسطة Google',
                      'Password is managed by Google',
                    ),
                  ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () async {
                    await AuthService().signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (_) => false,
                    );
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(context.tr('signOut')),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
