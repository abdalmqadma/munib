import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/prayer_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerProvider>();

    return Scaffold(
      backgroundColor: provider.isDarkMode ? const Color(0xFF071019) : const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    provider.language == 'English' ? 'Settings' : 'الإعدادات',
                    style: TextStyle(
                      color: provider.isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 28,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildSettingsCard(context, [
                      _buildSettingsTile(
                        context,
                        title: provider.language == 'English' ? 'Language' : 'لغة التطبيق',
                        subtitle: provider.language,
                        icon: Icons.language,
                        onTap: () => _showLanguageDialog(context, provider),
                      ),
                      _buildDivider(),
                      _buildSettingsTile(
                        context,
                        title: provider.language == 'English' ? 'Location' : 'المدينة',
                        subtitle: provider.currentCity,
                        icon: Icons.location_city,
                        onTap: () {}, // Handled by AI fetch usually
                      ),
                    ]),
                    const SizedBox(height: 30),
                    _buildSettingsCard(context, [
                      _buildSettingsTile(
                        context,
                        title: provider.language == 'English' ? 'Appearance' : 'مظهر التطبيق',
                        subtitle: provider.isDarkMode 
                          ? (provider.language == 'English' ? 'Dark' : 'داكن') 
                          : (provider.language == 'English' ? 'Light' : 'فاتح'),
                        icon: provider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        onTap: () => provider.updateSetting('isDarkMode', !provider.isDarkMode),
                      ),
                    ]),
                    const SizedBox(height: 30),
                    _buildSettingsCard(context, [
                      _buildSettingsTile(
                        context,
                        title: provider.language == 'English' ? 'Rate App' : 'تقييم التطبيق',
                        icon: Icons.star_outline_rounded,
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildSettingsTile(
                        context,
                        title: provider.language == 'English' ? 'Share' : 'مشاركة مع الأصدقاء',
                        icon: Icons.share_outlined,
                        onTap: () {},
                      ),
                    ]),
                    const SizedBox(height: 40),
                    Text(
                      provider.language == 'English' ? 'Muneeb - v1.0.0' : 'منيب - الإصدار 1.0.0',
                      style: const TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    final isDark = context.read<PrayerProvider>().isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final provider = context.read<PrayerProvider>();
    final isDark = provider.isDarkMode;
    final isEn = provider.language == 'English';

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Icon(isEn ? Icons.arrow_forward_ios : Icons.arrow_back_ios_new, color: Colors.white24, size: 16),
      title: Text(
        title,
        textAlign: isEn ? TextAlign.start : TextAlign.end,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              textAlign: isEn ? TextAlign.start : TextAlign.end,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            )
          : null,
      trailing: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.blueAccent.withValues(alpha: 0.7), size: 22),
      ),
    );
  }

  Widget _buildDivider() => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1, indent: 20, endIndent: 20);

  void _showLanguageDialog(BuildContext context, PrayerProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0B1724),
        title: Text(
          provider.language == 'English' ? 'Choose Language' : 'اختر اللغة',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('العربية', style: TextStyle(color: Colors.white)),
              onTap: () {
                provider.updateSetting('language', 'العربية');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('English', style: TextStyle(color: Colors.white)),
              onTap: () {
                provider.updateSetting('language', 'English');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
