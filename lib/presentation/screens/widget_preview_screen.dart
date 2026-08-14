import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/prayer_coach_provider.dart';
import 'prayer_coach/training_screen.dart';

class WidgetPreviewScreen extends StatelessWidget {
  const WidgetPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071019),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'اختر الصلاة',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const Text(
                'اختر الصلاة التي تريد تعلمها اليوم',
                style: TextStyle(color: Colors.white38, fontSize: 16),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  children: [
                    _buildPrayerOption(context, 'الفجر', 2, Icons.wb_twilight_rounded),
                    _buildPrayerOption(context, 'الظهر', 4, Icons.wb_sunny_rounded),
                    _buildPrayerOption(context, 'العصر', 4, Icons.filter_drama_rounded),
                    _buildPrayerOption(context, 'المغرب', 3, Icons.wb_twilight_sharp),
                    _buildPrayerOption(context, 'العشاء', 4, Icons.nightlight_round),
                    _buildLearningOption(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerOption(BuildContext context, String title, int rakahs, IconData icon) {
    return InkWell(
      onTap: () => _startTraining(context, title, rakahs),
      borderRadius: BorderRadius.circular(25),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFFFD166), size: 40),
            const SizedBox(height: 15),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('$rakahs ركعات', style: const TextStyle(color: Colors.white38, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningOption(BuildContext context) {
    return InkWell(
      onTap: () => _startTraining(context, 'الأساسيات', 0),
      borderRadius: BorderRadius.circular(25),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.blue, Color(0xFF1E88E5)]),
          borderRadius: BorderRadius.circular(25),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, color: Colors.white, size: 40),
            const SizedBox(height: 15),
            Text('تعلم الأساسيات', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('خطوة بخطوة', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _startTraining(BuildContext context, String prayerName, int rakahs) {
    context.read<PrayerCoachProvider>().startSession(rakahs);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrainingScreen(prayerName: prayerName)),
    );
  }
}
