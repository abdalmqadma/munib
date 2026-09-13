import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class FeedbackService {
  static const String formUrl =
      'https://docs.google.com/forms/d/e/1FAIpQLSflyBX884jBVdxUxJ-rB2GHWHHLi70klOraudF2dK9EJrN6dg/viewform?usp=header';

  static const String _launchCountKey = 'feedback_launch_count';
  static const String _promptShownKey = 'feedback_prompt_shown';
  static const int promptLaunchThreshold = 3;

  const FeedbackService._();

  static Future<void> registerAppLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_launchCountKey) ?? 0;
    await prefs.setInt(_launchCountKey, current + 1);
  }

  static Future<bool> shouldShowPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final launchCount = prefs.getInt(_launchCountKey) ?? 0;
    final alreadyShown = prefs.getBool(_promptShownKey) ?? false;
    return !alreadyShown && launchCount >= promptLaunchThreshold;
  }

  static Future<void> markPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptShownKey, true);
  }

  static Future<bool> openForm() {
    return launchUrl(
      Uri.parse(formUrl),
      mode: LaunchMode.externalApplication,
    );
  }
}
