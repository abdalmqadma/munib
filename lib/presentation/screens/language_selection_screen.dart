import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/prayer_provider.dart';
import 'splash_screen.dart';

class LanguageSelectionScreen extends StatelessWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071019),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.language_rounded, size: 80, color: Color(0xFFFFD166)),
              const SizedBox(height: 40),
              const Text(
                'اختر لغة التطبيق\nChoose App Language',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.5),
              ),
              const SizedBox(height: 60),
              _buildLanguageBtn(context, 'العربية', 'ar'),
              const SizedBox(height: 20),
              _buildLanguageBtn(context, 'English', 'en'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageBtn(BuildContext context, String label, String code) {
    return SizedBox(
      width: double.infinity,
      height: 65,
      child: ElevatedButton(
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('language', code);
          await prefs.setBool('isFirstRun', false);
          
          if (context.mounted) {
            context.read<PrayerProvider>().updateSetting('language', label);
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SplashScreen()));
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
