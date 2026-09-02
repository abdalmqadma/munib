import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_strings.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/profile_photo_service.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool photoBusy = false;
  bool _clearingUnverifiedSession = false;
  final _profilePhotoService = ProfilePhotoService();
  final _auth = AuthService();

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
            final name = AuthService.isValidDisplayName(savedName ?? '')
                ? AuthService.normalizeDisplayName(savedName!)
                : (AuthService.isValidDisplayName(authName ?? '')
                    ? AuthService.normalizeDisplayName(authName!)
                    : context.tr('munibUser'));
            final email = user.email ?? (data?['email'] as String?) ?? '';
            final savedPhoto = data?['photo_url'] as String?;
            final photo = savedPhoto?.trim().isNotEmpty == true
                ? savedPhoto
                : user.photoURL;

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
                  icon: Icons.email_outlined,
                  title: context.tr('email'),
                  value: email.isEmpty ? context.tr('notAvailable') : email,
                ),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: Icons.verified_user_outlined,
                  title: context.tr('accountType'),
                  value: user.providerData
                          .any((provider) => provider.providerId == 'google.com')
                      ? 'Google'
                      : context.tr('emailAccount'),
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
