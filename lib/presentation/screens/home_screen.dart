import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/munib_theme.dart';
import '../providers/prayer_provider.dart';
import '../widgets/munib_ultimate_widget.dart';
import '../widgets/prayer_grid_item.dart';
import 'auth_screen.dart';
import 'azkar_screen.dart';
import 'notifications_settings_screen.dart';
import 'settings_screen.dart';
import 'upload_screen.dart';
import 'widget_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _HomeDashboard(),
      const WidgetPreviewScreen(),
      const AzkarScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: MunibTheme.background,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: MunibTheme.surface,
          border: Border(top: BorderSide(color: MunibTheme.divider)),
        ),
        child: NavigationBar(
          height: 74,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule_rounded), label: 'المواقيت'),
            NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome_rounded), label: 'الأذكار'),
            NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'الإعدادات'),
          ],
        ),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard();

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerProvider>(
      builder: (context, provider, _) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
            children: [
              const _PremiumHeader(),
              const SizedBox(height: 18),
              const _LocationPill(),
              const SizedBox(height: 24),
              const _GreetingCard(),
              const SizedBox(height: 18),
              if (provider.monthlyPrayers.isEmpty)
                const _EmptyPrayerState()
              else ...[
                const MunibUltimateWidget(),
                const SizedBox(height: 24),
                const _SectionHeader(
                  title: 'مواقيت اليوم',
                  subtitle: 'حسب الإمساكية المحفوظة في منيب',
                ),
                const SizedBox(height: 12),
                PrayerGrid(),
                const SizedBox(height: 22),
                const _ProtectedDataCard(),
                const SizedBox(height: 18),
                const _UploadImsakiaButton(),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader();

  String _firstName(User? user) {
    final name = user?.displayName?.trim();
    if (name == null || name.isEmpty) return 'حسابي';
    return name.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final loggedIn = user != null;
        return Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => loggedIn ? const SettingsScreen() : const AuthScreen(),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: MunibTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MunibTheme.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: loggedIn ? const Color(0x334E87A1) : const Color(0x33D9A85A),
                      backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                      child: user?.photoURL == null
                          ? Icon(
                              loggedIn ? Icons.person_rounded : Icons.login_rounded,
                              size: 18,
                              color: loggedIn ? const Color(0xFF82B6CE) : MunibTheme.gold,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      loggedIn ? _firstName(user) : 'تسجيل الدخول',
                      style: const TextStyle(color: MunibTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('رفيقك اليومي', style: TextStyle(color: MunibTheme.textSecondary, fontSize: 11)),
                Text('مُنيب', style: TextStyle(color: MunibTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen()),
              ),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MunibTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: MunibTheme.divider),
                ),
                child: const Icon(Icons.notifications_none_rounded, color: MunibTheme.gold, size: 22),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LocationPill extends StatelessWidget {
  const _LocationPill();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2E38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x334E6571)),
      ),
      child: const Row(
        children: [
          Icon(Icons.keyboard_arrow_left_rounded, color: MunibTheme.goldSoft),
          Spacer(),
          Text('الموقع المحلي', style: TextStyle(color: MunibTheme.textSecondary, fontSize: 12)),
          SizedBox(width: 8),
          Icon(Icons.location_on_outlined, color: MunibTheme.goldSoft, size: 18),
        ],
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard();
  String _name() {
    final name = FirebaseAuth.instance.currentUser?.displayName?.trim();
    if (name == null || name.isEmpty) return 'بك';
    return 'يا ${name.split(RegExp(r'\s+')).first}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF173649), Color(0xFF102633)],
        ),
        border: Border.all(color: const Color(0x334E6571)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'السلام عليكم، ${_name()}',
            textAlign: TextAlign.right,
            style: const TextStyle(color: MunibTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          const Text('ليكن يومك عامراً بالسكينة.', textAlign: TextAlign.right, style: TextStyle(color: MunibTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _EmptyPrayerState extends StatelessWidget {
  const _EmptyPrayerState();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MunibTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: MunibTheme.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(color: Color(0x22D9A85A), shape: BoxShape.circle),
            child: const Icon(Icons.calendar_month_outlined, color: MunibTheme.gold, size: 34),
          ),
          const SizedBox(height: 20),
          const Text('أضف إمساكيتك', style: TextStyle(color: MunibTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'ارفع صورة الإمساكية ليقرأ منيب مواقيت الصلاة ويحفظها على جهازك.',
            textAlign: TextAlign.center,
            style: TextStyle(color: MunibTheme.textSecondary, height: 1.7),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadScreen())),
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('رفع الإمساكية'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('عرض الكل', style: TextStyle(color: MunibTheme.goldSoft, fontSize: 12)),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(title, style: const TextStyle(color: MunibTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(color: MunibTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class _ProtectedDataCard extends StatelessWidget {
  const _ProtectedDataCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: MunibTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MunibTheme.divider),
      ),
      child: const Row(
        children: [
          Icon(Icons.tune_rounded, color: MunibTheme.textSecondary, size: 18),
          Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('البيانات محفوظة بعناية', style: TextStyle(color: MunibTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              SizedBox(height: 2),
              Text('يمكنك تغيير الإمساكية في أي وقت', style: TextStyle(color: MunibTheme.textSecondary, fontSize: 10)),
            ],
          ),
          SizedBox(width: 10),
          Icon(Icons.shield_outlined, color: MunibTheme.goldSoft, size: 20),
        ],
      ),
    );
  }
}

class _UploadImsakiaButton extends StatelessWidget {
  const _UploadImsakiaButton();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadScreen())),
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('تغيير الإمساكية'),
      ),
    );
  }
}
