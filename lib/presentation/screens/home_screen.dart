import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/prayer_provider.dart';
import '../../data/services/location_service.dart';
import '../../data/services/ai_service.dart';
import '../../data/models/prayer_day.dart';
import 'upload_screen.dart';
import 'azkar_screen.dart';
import 'settings_screen.dart';
import 'widget_preview_screen.dart';
import 'notifications_settings_screen.dart';
import '../../core/app_colors.dart';
import '../widgets/munib_ultimate_widget.dart';
import '../widgets/prayer_grid_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeContentPlaceholder(),
    const AzkarScreen(),
    const WidgetPreviewScreen(),
    const SettingsScreen(),
  ];

  Color _getBackgroundColor(String nextPrayer) {
    switch (nextPrayer.toLowerCase()) {
      case 'maghrib':
        return const Color(0xFF1A1210);
      case 'isha':
      case 'fajr':
        return const Color(0xFF071019);
      default:
        return const Color(0xFF0D1B2A);
    }
  }

  Color _getAccentColor(String nextPrayer) {
    return nextPrayer.toLowerCase() == 'maghrib' 
        ? const Color(0xFFE96443) 
        : const Color(0xFF1E88E5);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerProvider>(
      builder: (context, provider, child) {
        final nextPrayer = provider.nextPrayerName;
        final bgColor = _getBackgroundColor(nextPrayer);

        return Scaffold(
          backgroundColor: bgColor,
          body: _currentIndex == 0 
              ? HomeContent(
                  nextPrayer: nextPrayer,
                  onStartTraining: () => setState(() => _currentIndex = 2),
                ) 
              : _screens[_currentIndex],
          bottomNavigationBar: _buildBottomNav(nextPrayer),
        );
      },
    );
  }

  Widget _buildBottomNav(String nextPrayer) {
    final accentColor = _getAccentColor(nextPrayer);
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: Colors.transparent,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: accentColor,
        unselectedItemColor: Colors.white24,
        elevation: 0,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.nightlight_round), label: 'الأذكار'),
          BottomNavigationBarItem(icon: Icon(Icons.widgets_outlined), label: 'التدريب'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

class HomeContentPlaceholder extends StatelessWidget {
  const HomeContentPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class HomeContent extends StatefulWidget {
  final String nextPrayer;
  final VoidCallback onStartTraining;
  const HomeContent({super.key, required this.nextPrayer, required this.onStartTraining});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  bool _isAutoFetching = false;
  String _locationName = "الموقع غير محدد";

  Future<void> _fetchByLocation(BuildContext context) async {
    setState(() => _isAutoFetching = true);
    final provider = context.read<PrayerProvider>();
    final locationService = LocationService();
    final aiService = AIService();

    try {
      final city = await locationService.getCurrentCity();
      if (mounted) setState(() => _locationName = city);
      final structuredData = await aiService.fetchPrayerTimesByLocation(city);
      
      if (structuredData.isNotEmpty) {
        final prayers = structuredData.map((e) => PrayerDay.fromJson(e)).toList();
        await provider.setMonthlyPrayers(prayers);
      } else {
        throw Exception("Failed to fetch data");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("لم نتمكن من جلب الأوقات تلقائياً، يرجى رفع الإمساكية يدوياً")),
        );
      }
    } finally {
      if (mounted) setState(() => _isAutoFetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerProvider>(
      builder: (context, provider, child) {
        if (provider.monthlyPrayers.isEmpty) {
          if (_isAutoFetching) return _buildLoadingSkeleton();
          return _buildEmptyState(context);
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildHeader(context),
                const SizedBox(height: 30),
                const MunibUltimateWidget(),
                const SizedBox(height: 30),
                _buildCoachCard(context),
                const SizedBox(height: 30),
                const PrayerGrid(),
                const SizedBox(height: 30),
                _buildUploadButton(context, widget.nextPrayer),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 45, height: 45, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle)),
                Container(width: 120, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10))),
              ],
            ),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              height: 280,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(35)),
            ),
            const SizedBox(height: 30),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 0.85,
              children: List.generate(6, (index) => Container(
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(25)),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        width: 80,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      )),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2E3D),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(Icons.question_mark_rounded, color: Colors.white38, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              const Text(
                'لا توجد أوقات صلاة',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'ارفع إمساكيتك أو دع منيب يجلبها بناءً على موقعك',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 40),
              
              if (_isAutoFetching)
                const CircularProgressIndicator(color: Color(0xFFFFD166))
              else ...[
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () => _fetchByLocation(context),
                    icon: const Icon(Icons.location_on, color: Colors.white),
                    label: const Text('جلب أوقات مدينتي تلقائياً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text('أو', style: TextStyle(color: Colors.white10)),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UploadScreen()),
                    ),
                    icon: const Icon(Icons.upload_rounded, color: Colors.white70),
                    label: const Text('رفع صورة الإمساكية', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications, color: Color(0xFFFFD166), size: 28),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('،أهلاً', style: TextStyle(color: Colors.white38, fontSize: 14)),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.pinkAccent, size: 16),
                const SizedBox(width: 4),
                Text(
                  _locationName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUploadButton(BuildContext context, String nextPrayer) {
    final btnColor = nextPrayer.toLowerCase() == 'maghrib' 
        ? const Color(0xFF1E88E5) 
        : const Color(0xFFFFD166);
    
    return Center(
      child: SizedBox(
        width: 250,
        height: 60,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadScreen())),
          icon: Icon(Icons.cloud_upload_outlined, color: nextPrayer.toLowerCase() == 'maghrib' ? Colors.white : Colors.blue),
          label: Text(
            'تغيير الإمساكية',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: nextPrayer.toLowerCase() == 'maghrib' ? Colors.white : Colors.black87),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: btnColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ),
    );
  }

  Widget _buildCoachCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.accessibility_new_rounded, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 15),
              const Text(
                'علّمني الصلاة',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            'تعلّم الصلاة خطوة بخطوة مع مدرب ذكي يتابع حركاتك ويساعدك على التحسن.',
            style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: widget.onStartTraining,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text('ابدأ التدريب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroPrayerCard extends StatelessWidget {
  final String nextPrayer;
  const HeroPrayerCard({super.key, required this.nextPrayer});

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerProvider>(
      builder: (context, provider, child) {
        final isSunset = nextPrayer.toLowerCase() == 'maghrib';
        final cardColor = isSunset ? const Color(0xFF2D1F1A) : Colors.white.withValues(alpha: 0.05);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Text(
                DateFormat('HH:mm').format(DateTime.now()),
                style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold),
              ),
              Text(
                "${DateFormat('EEEE، d يونيو 2026', 'ar').format(DateTime.now())}  •  3 محرم 1448",
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                '+ حانت صلاة $nextPrayer الآن',
                style: const TextStyle(color: Color(0xFFFFD166), fontSize: 14),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(child: _buildInfoBox(provider.timeLeftFormatted, 'المتبقي', isHighlighted: true)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildInfoBox(nextPrayer, 'الصلاة القادمة', icon: isSunset ? '🌇' : '🌙')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoBox(String value, String label, {String? icon, bool isHighlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: isHighlighted ? Border.all(color: Colors.white10) : null,
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white24, fontSize: 11)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) Text(icon, style: const TextStyle(fontSize: 16)),
              if (icon != null) const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  color: isHighlighted ? const Color(0xFFFFC107) : Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PrayerGrid extends StatelessWidget {
  const PrayerGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerProvider>(
      builder: (context, provider, child) {
        final currentDay = provider.currentDay;
        if (currentDay == null) return const SizedBox.shrink();

        final nextPrayer = provider.nextPrayerName.toLowerCase();

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 0.82,
          children: [
            PrayerGridItem(
              name: 'الفجر',
              time: currentDay.fajr,
              icon: Icons.brightness_3_rounded, // هلال الفجر
              isActive: nextPrayer == 'fajr',
            ),
            PrayerGridItem(
              name: 'الشروق',
              time: currentDay.sunrise,
              icon: Icons.wb_sunny_outlined,
              isActive: nextPrayer == 'sunrise',
            ),
            PrayerGridItem(
              name: 'الظهر',
              time: currentDay.dhuhr,
              icon: Icons.wb_sunny_rounded,
              isActive: nextPrayer == 'dhuhr',
            ),
            PrayerGridItem(
              name: 'العصر',
              time: currentDay.asr,
              icon: Icons.wb_cloudy_rounded, // شمس خلف غيمة للعصر
              isActive: nextPrayer == 'asr',
            ),
            PrayerGridItem(
              name: 'المغرب',
              time: currentDay.maghrib,
              icon: Icons.wb_twilight_rounded, // أيقونة الغروب الحقيقية
              isActive: nextPrayer == 'maghrib',
            ),
            PrayerGridItem(
              name: 'العشاء',
              time: currentDay.isha,
              icon: Icons.nightlight_round_sharp,
              isActive: nextPrayer == 'isha',
            ),
          ],
        );
      },
    );
  }
}
