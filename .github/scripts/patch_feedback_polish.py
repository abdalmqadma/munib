from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    Path(path).write_text(content, encoding="utf-8")


def replace_once(content: str, old: str, new: str, label: str) -> str:
    if old not in content:
        raise SystemExit(f"Missing patch marker: {label}")
    return content.replace(old, new, 1)


# 1) Shared feedback service: launch counting + one-time prompt + form opening.
service_path = Path("lib/data/services/feedback_service.dart")
service_path.write_text(
    """import 'package:shared_preferences/shared_preferences.dart';
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
""",
    encoding="utf-8",
)

# 2) Count a launch once per real app process startup.
main_path = "lib/main.dart"
main = read(main_path)
main = replace_once(
    main,
    "import 'data/services/analytics_service.dart';\n",
    "import 'data/services/analytics_service.dart';\nimport 'data/services/feedback_service.dart';\n",
    "main feedback import",
)
main = replace_once(
    main,
    "  await NotificationService.init();\n\n  try {",
    "  await NotificationService.init();\n  await FeedbackService.registerAppLaunch();\n\n  try {",
    "register app launch",
)
write(main_path, main)

# 3) Home: remove duplicate next-prayer summary and show one-time prompt on third launch.
home_path = "lib/presentation/screens/home_screen.dart"
home = read(home_path)
home = replace_once(
    home,
    "import '../../data/services/ai_service.dart';\n",
    "import '../../data/services/ai_service.dart';\nimport '../../data/services/feedback_service.dart';\n",
    "home feedback import",
)
home = replace_once(
    home,
    "    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeNafahatNavigation());\n",
    "    WidgetsBinding.instance.addPostFrameCallback((_) => _handleInitialTasks());\n",
    "home initial task callback",
)
home = replace_once(
    home,
    "  Future<void> _consumeNafahatNavigation() async {\n    final category = await _nafahatBridge.consumePendingAzkarNavigation();\n    if (!mounted || category == null) return;\n    setState(() => _azkarCategory = category);\n    _goTo(1);\n  }\n",
    """  Future<void> _handleInitialTasks() async {
    await _consumeNafahatNavigation();
    if (!mounted) return;
    await _maybeShowFeedbackPrompt();
  }

  Future<void> _consumeNafahatNavigation() async {
    final category = await _nafahatBridge.consumePendingAzkarNavigation();
    if (!mounted || category == null) return;
    setState(() => _azkarCategory = category);
    _goTo(1);
  }

  Future<void> _maybeShowFeedbackPrompt() async {
    if (!await FeedbackService.shouldShowPrompt() || !mounted) return;

    await FeedbackService.markPromptShown();
    if (!mounted) return;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final openForm = await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          useSafeArea: true,
          builder: (sheetContext) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 38,
                  color: Theme.of(sheetContext).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  isArabic
                      ? 'ساعدنا في تحسين التطبيق'
                      : 'Help us improve the app',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic
                      ? 'شاركنا رأيك من خلال نموذج منيب.'
                      : 'Share your feedback through the Munib form.',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(isArabic ? 'فتح النموذج' : 'Open form'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: Text(isArabic ? 'لاحقًا' : 'Later'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!openForm) return;
    final opened = await FeedbackService.openForm();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تعذر فتح نموذج منيب. حاول مرة أخرى من الإعدادات.'
                : 'Could not open the Munib form. Try again from Settings.',
          ),
        ),
      );
    }
  }
""",
    "home feedback methods",
)
home = replace_once(
    home,
    "              const MunibUltimateWidget(),\n              const SizedBox(height: 24),\n              _NextPrayerSummary(provider: provider),\n              const SizedBox(height: 24),\n              _PrayerTimesSection(provider: provider),",
    "              const MunibUltimateWidget(),\n              const SizedBox(height: 24),\n              _PrayerTimesSection(provider: provider),",
    "remove duplicate summary from home",
)
start = home.find("class _NextPrayerSummary extends StatelessWidget {")
end = home.find("class _PrayerTimesSection extends StatefulWidget {")
if start == -1 or end == -1 or end <= start:
    raise SystemExit("Could not locate duplicate next-prayer summary class")
home = home[:start] + home[end:]
write(home_path, home)

# 4) Settings: permanent feedback entry that immediately opens the form.
settings_path = "lib/presentation/screens/settings_screen.dart"
settings = read(settings_path)
settings = replace_once(
    settings,
    "import '../../data/services/ai_service.dart';\n",
    "import '../../data/services/ai_service.dart';\nimport '../../data/services/feedback_service.dart';\n",
    "settings feedback import",
)
legal_marker = """                    const SizedBox(height: 24),
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          title: t('شروط الاستخدام', 'Terms of Use'),"""
feedback_block = """                    const SizedBox(height: 24),
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          title: t(
                            'ساعدنا في تحسين التطبيق',
                            'Help us improve the app',
                          ),
                          subtitle: t(
                            'شاركنا رأيك من خلال نموذج منيب',
                            'Share your feedback through the Munib form',
                          ),
                          icon: Icons.rate_review_outlined,
                          onTap: () async {
                            final opened = await FeedbackService.openForm();
                            if (!opened && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    t(
                                      'تعذر فتح نموذج منيب. حاول مرة أخرى.',
                                      'Could not open the Munib form. Please try again.',
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SettingsCard(
                      children: [
                        _SettingsTile(
                          title: t('شروط الاستخدام', 'Terms of Use'),"""
settings = replace_once(settings, legal_marker, feedback_block, "settings feedback card")
write(settings_path, settings)

# 5) Focused unit tests for the third-launch one-time gate.
test_path = Path("test/feedback_service_test.dart")
test_path.write_text(
    """import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:munib/data/services/feedback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('feedback prompt stays hidden before the third launch', () async {
    await FeedbackService.registerAppLaunch();
    await FeedbackService.registerAppLaunch();

    expect(await FeedbackService.shouldShowPrompt(), isFalse);
  });

  test('feedback prompt becomes available on the third launch', () async {
    await FeedbackService.registerAppLaunch();
    await FeedbackService.registerAppLaunch();
    await FeedbackService.registerAppLaunch();

    expect(await FeedbackService.shouldShowPrompt(), isTrue);
  });

  test('feedback prompt does not return after it has been shown', () async {
    await FeedbackService.registerAppLaunch();
    await FeedbackService.registerAppLaunch();
    await FeedbackService.registerAppLaunch();
    await FeedbackService.markPromptShown();

    expect(await FeedbackService.shouldShowPrompt(), isFalse);
  });
}
""",
    encoding="utf-8",
)

print("Applied home cleanup and feedback flow patch")
