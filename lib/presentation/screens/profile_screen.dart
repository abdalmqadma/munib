import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_strings.dart';
import '../../data/services/auth_service.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final scheme = Theme.of(context).colorScheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('profile'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton.icon(
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen(returnOnSuccess: true)),
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
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile'))),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final name = (data?['name'] as String?)?.trim().isNotEmpty == true
                ? data!['name'] as String
                : (user.displayName?.trim().isNotEmpty == true
                    ? user.displayName!
                    : context.tr('munibUser'));
            final email = user.email ?? (data?['email'] as String?) ?? '';

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: scheme.outline),
                    ),
                    child: Column(
                      children: [
                        _Avatar(user: user, radius: 46),
                        const SizedBox(height: 18),
                        Text(
                          name,
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
                    value: user.providerData.any((p) => p.providerId == 'google.com')
                        ? 'Google'
                        : context.tr('emailAccount'),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
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
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final User user;
  final double radius;

  const _Avatar({required this.user, required this.radius});

  @override
  Widget build(BuildContext context) {
    final photo = user.photoURL;
    final scheme = Theme.of(context).colorScheme;

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
      child: photo == null || photo.isEmpty
          ? Icon(Icons.person_rounded, size: radius, color: scheme.primary)
          : null,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({required this.icon, required this.title, required this.value});

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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: scheme.primary),
          ),
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
