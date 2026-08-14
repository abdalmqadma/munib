import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'language_selection_screen.dart';
import 'onboarding_screen.dart';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final bool isFirstRun = prefs.getBool('isFirstRun') ?? true;
    final String? lang = prefs.getString('language');
    final User? user = FirebaseAuth.instance.currentUser;

    Widget nextScreen;
    if (lang == null) {
      nextScreen = const LanguageSelectionScreen();
    } else if (isFirstRun) {
      nextScreen = const OnboardingScreen();
    } else if (user == null) {
      nextScreen = const AuthScreen();
    } else {
      nextScreen = const HomeScreen();
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071019),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: const Center(child: Icon(Icons.nightlight_round, color: Color(0xFFFFD166), size: 45)),
              ),
              const SizedBox(height: 35),
              const Text('منيب', style: TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900)),
              const Text('M U N E E B', style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 8)),
            ],
          ),
        ),
      ),
    );
  }
}
