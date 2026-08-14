import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/prayer_provider.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF071019),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                    child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                  ),
                  const Text('الإشعارات', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        children: [
                          _buildSwitchTile(
                            title: 'إشعارات الصلاة',
                            subtitle: 'تنبيه عند كل وقت صلاة',
                            icon: Icons.notifications_active,
                            value: provider.prayerNotif,
                            onChanged: (val) => provider.updateSetting('prayerNotif', val),
                          ),
                          _buildDivider(),
                          _buildSwitchTile(
                            title: 'تذكير قبل الصلاة',
                            subtitle: '15 دقيقة قبل الأذان',
                            icon: Icons.alarm,
                            value: provider.reminderNotif,
                            onChanged: (val) => provider.updateSetting('reminderNotif', val),
                          ),
                          _buildDivider(),
                          _buildSwitchTile(
                            title: 'أذكار الصباح',
                            subtitle: 'بعد صلاة الفجر',
                            icon: Icons.wb_sunny_outlined,
                            value: provider.azkarNotif,
                            onChanged: (val) => provider.updateSetting('azkarNotif', val),
                          ),
                          _buildDivider(),
                          _buildSwitchTile(
                            title: 'الوضع الصامت',
                            subtitle: 'إشعارات بدون صوت',
                            icon: Icons.volume_off_rounded,
                            value: provider.silentMode,
                            onChanged: (val) => provider.updateSetting('silentMode', val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Padding(padding: EdgeInsets.only(right: 10, bottom: 15), child: Text('صوت الأذان', style: TextStyle(color: Colors.white38, fontSize: 16))),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        children: [
                          _buildRadioTile(
                            title: 'المكي الافتراضي',
                            subtitle: 'أذان مكة المكرمة',
                            icon: Icons.music_note_rounded,
                            isSelected: provider.adhanVoice == 'Meccan',
                            onTap: () => provider.updateSetting('adhanVoice', 'Meccan'),
                          ),
                          _buildDivider(),
                          _buildRadioTile(
                            title: 'بدون أذان',
                            subtitle: 'تنبيه صامت فقط',
                            icon: Icons.notifications_off_outlined,
                            isSelected: provider.adhanVoice == 'None',
                            onTap: () => provider.updateSetting('adhanVoice', 'None'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({required String title, required String subtitle, required IconData icon, required bool value, required Function(bool) onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF1E88E5)),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ]),
          const SizedBox(width: 20),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle), child: Icon(icon, color: const Color(0xFFFFD166), size: 24)),
        ],
      ),
    );
  }

  Widget _buildRadioTile({required String title, required String subtitle, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? const Color(0xFF1E88E5) : Colors.white24, width: 2)), child: isSelected ? Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle))) : null),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 13)),
            ]),
            const SizedBox(width: 20),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: Colors.blueAccent.withOpacity(0.5), size: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() => Divider(color: Colors.white.withOpacity(0.05), height: 1, indent: 20, endIndent: 20);
}
