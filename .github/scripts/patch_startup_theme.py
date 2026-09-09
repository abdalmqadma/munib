from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'anchor not found in {path}: {old[:80]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


# 1) Splash: real Munib brand mark + localized name; no language chooser.
splash = Path('lib/presentation/screens/splash_screen.dart')
splash.write_text(r'''import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/auth_service.dart';
import '../../data/services/push_notification_service.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .82, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: .92, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    try {
      await AuthService().signOutUnverifiedPasswordUser();
    } catch (_) {
      // Authentication cleanup is best-effort. Never trap the user on splash.
    }

    final prefs = await SharedPreferences.getInstance();
    final isFirstRun = prefs.getBool('isFirstRun') ?? true;

    final Widget nextScreen;
    final String nextRouteName;
    if (isFirstRun) {
      nextScreen = const OnboardingScreen();
      nextRouteName = '/onboarding';
    } else {
      final pushDestination = PushNotificationService.takeDeferredDestination();
      nextScreen = HomeScreen(
        initialIndex: pushDestination?.homeIndex ?? 0,
        initialAzkarCategory:
            pushDestination?.initialAzkarCategory ?? 'Morning',
      );
      nextRouteName = '/home';
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: RouteSettings(name: nextRouteName),
        builder: (_) => nextScreen,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Semantics(
              image: true,
              label: isArabic ? 'منيب' : 'Munib',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png',
                    width: 132,
                    height: 132,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isArabic ? 'منيب' : 'Munib',
                    textDirection:
                        isArabic ? TextDirection.rtl : TextDirection.ltr,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: isArabic ? 0 : .3,
                      color: dark
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
''', encoding='utf-8')

# 2) Bundle the real adaptive-icon foreground for Flutter splash use.
replace_once(
    'pubspec.yaml',
    '    - assets/muneeb_icons/store/\n',
    '    - assets/muneeb_icons/store/\n'
    '    - android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png\n',
)

# 3) First run language = device language; persist it so settings remain canonical.
replace_once(
    'lib/presentation/providers/prayer_provider.dart',
    "import 'dart:async';\n",
    "import 'dart:async';\nimport 'dart:ui' as ui;\n",
)
replace_once(
    'lib/presentation/providers/prayer_provider.dart',
    "  String language = 'العربية';\n",
    "  String language = ui.PlatformDispatcher.instance.locale.languageCode\n"
    "          .toLowerCase()\n"
    "          .startsWith('ar')\n"
    "      ? 'العربية'\n"
    "      : 'English';\n",
)
replace_once(
    'lib/presentation/providers/prayer_provider.dart',
    "    final prefs = await SharedPreferences.getInstance();\n    _readSettings(prefs);\n",
    "    final prefs = await SharedPreferences.getInstance();\n"
    "    final hadSavedLanguage = prefs.getString('language') != null;\n"
    "    _readSettings(prefs);\n"
    "    if (!hadSavedLanguage) {\n"
    "      await prefs.setString('language', languageCode);\n"
    "    }\n",
)
replace_once(
    'lib/presentation/providers/prayer_provider.dart',
    "    final savedLanguage = prefs.getString('language') ?? 'ar';\n"
    "    language = savedLanguage == 'en' || savedLanguage == 'English'\n"
    "        ? 'English'\n"
    "        : 'العربية';\n",
    "    final savedLanguage = prefs.getString('language');\n"
    "    if (savedLanguage != null) {\n"
    "      language = savedLanguage == 'en' || savedLanguage == 'English'\n"
    "          ? 'English'\n"
    "          : 'العربية';\n"
    "    } else {\n"
    "      final deviceLanguage =\n"
    "          ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();\n"
    "      language = deviceLanguage.startsWith('ar') ? 'العربية' : 'English';\n"
    "    }\n",
)

# Push routing no longer waits for a manual language selection screen.
replace_once(
    'lib/main.dart',
    "    final languageSelected = prefs.getString('language') != null;\n"
    "    final onboardingDone = !(prefs.getBool('isFirstRun') ?? true);\n\n"
    "    if (!languageSelected || !onboardingDone) {\n",
    "    final onboardingDone = !(prefs.getBool('isFirstRun') ?? true);\n\n"
    "    if (!onboardingDone) {\n",
)

# 4) Persist theme preference for native Android/iOS widget extensions.
replace_once(
    'lib/features/settings/presentation/theme_provider.dart',
    "import 'package:shared_preferences/shared_preferences.dart';\n",
    "import 'package:shared_preferences/shared_preferences.dart';\n\n"
    "import '../../prayer_times/data/widget_service.dart';\n",
)
replace_once(
    'lib/features/settings/presentation/theme_provider.dart',
    "    _preference = MunibThemePreference.values.firstWhere(\n"
    "      (e) => e.name == saved,\n"
    "      orElse: () => MunibThemePreference.system,\n"
    "    );\n"
    "    notifyListeners();\n",
    "    _preference = MunibThemePreference.values.firstWhere(\n"
    "      (e) => e.name == saved,\n"
    "      orElse: () => MunibThemePreference.system,\n"
    "    );\n"
    "    await WidgetService.saveThemePreference(_preference.name);\n"
    "    notifyListeners();\n",
)
replace_once(
    'lib/features/settings/presentation/theme_provider.dart',
    "    await prefs.setString(_key, value.name);\n    notifyListeners();\n",
    "    await prefs.setString(_key, value.name);\n"
    "    await WidgetService.saveThemePreference(value.name);\n"
    "    notifyListeners();\n",
)

replace_once(
    'lib/features/prayer_times/data/widget_service.dart',
    "  static Future<void> saveLocation(String locationName) async {\n",
    "  static Future<void> saveThemePreference(String preference) async {\n"
    "    try {\n"
    "      await _preparePlatform();\n"
    "      final normalized = switch (preference) {\n"
    "        'light' => 'light',\n"
    "        'dark' => 'dark',\n"
    "        _ => 'system',\n"
    "      };\n"
    "      await HomeWidget.saveWidgetData<String>(\n"
    "        'widget_theme_preference',\n"
    "        normalized,\n"
    "      );\n"
    "      await _refreshAll();\n"
    "    } catch (e) {\n"
    "      debugPrint('Error saving widget theme preference: $e');\n"
    "    }\n"
    "  }\n\n"
    "  static Future<void> saveLocation(String locationName) async {\n",
)

# 5) Android Home Screen widgets: theme from Munib preference.
scheduler = Path('android/app/src/main/kotlin/com/example/munib/PrayerWidgetScheduler.kt')
text = scheduler.read_text(encoding='utf-8')
text = text.replace('import android.content.Intent\n', 'import android.content.Intent\nimport android.content.res.Configuration\n', 1)
text = text.replace(
    '        val locationName = prefs.getString("widget_location", "")?.trim().orEmpty()\n',
    '        val locationName = prefs.getString("widget_location", "")?.trim().orEmpty()\n'
    '        val darkWidget = useDarkWidgetPalette(context, prefs.getString("widget_theme_preference", "system"))\n'
    '        val primaryText = if (darkWidget) Color.WHITE else Color.rgb(24, 31, 28)\n'
    '        val secondaryText = if (darkWidget) Color.argb(191, 255, 255, 255) else Color.rgb(92, 101, 97)\n'
    '        val bodyText = if (darkWidget) Color.argb(230, 255, 255, 255) else Color.rgb(45, 54, 50)\n'
    '        val accentText = if (darkWidget) Color.rgb(244, 199, 106) else Color.rgb(166, 116, 38)\n',
    1,
)
if 'import android.graphics.Color\n' not in text:
    text = text.replace('import android.content.res.Configuration\n', 'import android.content.res.Configuration\nimport android.graphics.Color\n', 1)
anchor = '            views.setImageViewResource(R.id.widget_bg_icon, iconRes)\n            views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_glass_background)\n'
replacement = '''            views.setImageViewResource(R.id.widget_bg_icon, iconRes)
            views.setInt(
                R.id.widget_root,
                "setBackgroundResource",
                if (darkWidget) R.drawable.widget_glass_background else R.drawable.widget_light_background,
            )
            views.setInt(
                R.id.widget_icon_container,
                "setBackgroundResource",
                if (darkWidget) R.drawable.widget_prayer_icon_circle else R.drawable.widget_prayer_icon_circle_light,
            )
            when (layoutRes) {
                R.layout.widget_small -> views.setInt(
                    R.id.widget_small_hero,
                    "setBackgroundResource",
                    if (darkWidget) R.drawable.widget_glass_panel else R.drawable.widget_light_panel,
                )
                R.layout.widget_medium -> views.setInt(
                    R.id.widget_medium_hero,
                    "setBackgroundResource",
                    if (darkWidget) R.drawable.widget_glass_panel else R.drawable.widget_light_panel,
                )
                R.layout.widget_large -> views.setInt(
                    R.id.widget_large_hero,
                    "setBackgroundResource",
                    if (darkWidget) R.drawable.widget_glass_panel else R.drawable.widget_light_panel,
                )
            }
            views.setTextColor(R.id.widget_next_label, secondaryText)
            views.setTextColor(R.id.widget_next_prayer, accentText)
            views.setTextColor(R.id.widget_time_left, primaryText)
            views.setTextColor(R.id.widget_remaining_label, accentText)
            views.setTextColor(R.id.widget_dhikr, bodyText)
            views.setTextColor(R.id.widget_date, secondaryText)
            views.setTextColor(R.id.widget_current_time, primaryText)
            if (layoutRes == R.layout.widget_large) {
                views.setTextColor(R.id.widget_location, accentText)
            }
'''
if anchor not in text:
    raise SystemExit('Android scheduler active theme anchor not found')
text = text.replace(anchor, replacement, 1)

old_empty = '''        val openApp = launchPendingIntent(context)
        for ((provider, layout) in providers) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider))
            for (id in ids) {
                val views = RemoteViews(context.packageName, layout)
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_glass_background)
                views.setViewVisibility(R.id.widget_active_layout, View.GONE)
                views.setViewVisibility(R.id.widget_empty_layout, View.VISIBLE)
                views.setTextViewText(R.id.widget_empty_message, message)
'''
new_empty = '''        val openApp = launchPendingIntent(context)
        val darkWidget = useDarkWidgetPalette(
            context,
            prefs.getString("widget_theme_preference", "system"),
        )
        val emptyText = if (darkWidget) Color.argb(230, 255, 255, 255) else Color.rgb(45, 54, 50)
        for ((provider, layout) in providers) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider))
            for (id in ids) {
                val views = RemoteViews(context.packageName, layout)
                views.setInt(
                    R.id.widget_root,
                    "setBackgroundResource",
                    if (darkWidget) R.drawable.widget_glass_background else R.drawable.widget_light_background,
                )
                views.setViewVisibility(R.id.widget_active_layout, View.GONE)
                views.setViewVisibility(R.id.widget_empty_layout, View.VISIBLE)
                views.setTextViewText(R.id.widget_empty_message, message)
                views.setTextColor(R.id.widget_empty_message, emptyText)
'''
if old_empty not in text:
    raise SystemExit('Android scheduler empty theme anchor not found')
text = text.replace(old_empty, new_empty, 1)

helper_anchor = '    private fun launchPendingIntent(context: Context): PendingIntent {\n'
helper = '''    private fun useDarkWidgetPalette(context: Context, rawPreference: String?): Boolean {
        return when (rawPreference?.lowercase()) {
            "dark" -> true
            "light" -> false
            else -> {
                val mode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
                mode == Configuration.UI_MODE_NIGHT_YES
            }
        }
    }

'''
if helper_anchor not in text:
    raise SystemExit('Android scheduler helper anchor not found')
text = text.replace(helper_anchor, helper + helper_anchor, 1)
scheduler.write_text(text, encoding='utf-8')

# Light Android resources.
Path('android/app/src/main/res/drawable/widget_light_background.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:angle="315" android:startColor="#FFFDFBF7" android:centerColor="#FFF7F4EE" android:endColor="#FFFFFFFF" />
    <corners android:radius="24dp" />
    <stroke android:width="1dp" android:color="#33B88636" />
</shape>
''', encoding='utf-8')
Path('android/app/src/main/res/drawable/widget_light_panel.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#0D16352E" />
    <corners android:radius="16dp" />
    <stroke android:width="1dp" android:color="#1416352E" />
</shape>
''', encoding='utf-8')
Path('android/app/src/main/res/drawable/widget_prayer_icon_circle_light.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval">
    <solid android:color="#1016352E" />
    <stroke android:width="5dp" android:color="#0D16352E" />
</shape>
''', encoding='utf-8')

# 6) iOS Home Screen widgets follow Munib theme; lock widget stays system/vibrant.
ios = Path('ios/PrayerWidgetExtension/PrayerWidget.swift')
text = ios.read_text(encoding='utf-8')
text = text.replace(
    '    let use24HourFormat: Bool\n\n    var isArabic: Bool {',
    '    let use24HourFormat: Bool\n    let themePreference: String\n\n    var isArabic: Bool {',
    1,
)
text = text.replace(
    '            use24HourFormat: true\n        )',
    '            use24HourFormat: true,\n            themePreference: "system"\n        )',
    1,
)
text = text.replace(
    '            use24HourFormat: defaults.object(forKey: "widget_use_24h") as? Bool ?? true\n        )',
    '            use24HourFormat: defaults.object(forKey: "widget_use_24h") as? Bool ?? true,\n'
    '            themePreference: defaults.string(forKey: "widget_theme_preference") ?? "system"\n        )',
    1,
)
text = text.replace(
    '    @Environment(\\.widgetFamily) private var family\n    let entry: PrayerWidgetEntry\n\n    private let gold = Color(red: 244 / 255, green: 199 / 255, blue: 106 / 255)\n    private let mutedWhite = Color.white.opacity(0.76)\n',
    '    @Environment(\\.widgetFamily) private var family\n'
    '    @Environment(\\.colorScheme) private var systemColorScheme\n'
    '    let entry: PrayerWidgetEntry\n\n'
    '    private let gold = Color(red: 244 / 255, green: 199 / 255, blue: 106 / 255)\n\n'
    '    private var usesDarkPalette: Bool {\n'
    '        switch entry.themePreference.lowercased() {\n'
    '        case "dark": return true\n'
    '        case "light": return false\n'
    '        default: return systemColorScheme == .dark\n'
    '        }\n'
    '    }\n\n'
    '    private var primaryText: Color {\n'
    '        usesDarkPalette ? .white : Color(red: 24 / 255, green: 31 / 255, blue: 28 / 255)\n'
    '    }\n\n'
    '    private var secondaryText: Color {\n'
    '        usesDarkPalette ? Color.white.opacity(0.76) : Color(red: 92 / 255, green: 101 / 255, blue: 97 / 255)\n'
    '    }\n\n'
    '    private var bodyText: Color {\n'
    '        usesDarkPalette ? Color.white.opacity(0.9) : Color(red: 45 / 255, green: 54 / 255, blue: 50 / 255)\n'
    '    }\n\n'
    '    private var panelColor: Color {\n'
    '        usesDarkPalette ? Color.white.opacity(0.08) : Color(red: 22 / 255, green: 53 / 255, blue: 46 / 255).opacity(0.06)\n'
    '    }\n\n'
    '    private var listPanelColor: Color {\n'
    '        usesDarkPalette ? Color.black.opacity(0.12) : Color(red: 22 / 255, green: 53 / 255, blue: 46 / 255).opacity(0.05)\n'
    '    }\n\n'
    '    private var dividerColor: Color {\n'
    '        usesDarkPalette ? Color.white.opacity(0.12) : Color.black.opacity(0.08)\n'
    '    }\n\n'
    '    private var iconBackground: Color {\n'
    '        usesDarkPalette\n'
    '            ? Color(red: 11 / 255, green: 31 / 255, blue: 58 / 255)\n'
    '            : Color(red: 22 / 255, green: 53 / 255, blue: 46 / 255).opacity(0.08)\n'
    '    }\n',
    1,
)
text = text.replace('.munibWidgetBackground()', '.munibWidgetBackground(isDark: usesDarkPalette)', 1)
text = text.replace('mutedWhite', 'secondaryText')
text = text.replace('.foregroundStyle(.white)', '.foregroundStyle(primaryText)')
text = text.replace('.foregroundStyle(Color.white.opacity(0.9))', '.foregroundStyle(bodyText)')
text = text.replace('.foregroundStyle(Color.white.opacity(0.88))', '.foregroundStyle(bodyText)')
text = text.replace('.background(Color.white.opacity(0.08), in:', '.background(panelColor, in:')
text = text.replace('Divider().overlay(Color.white.opacity(0.12))', 'Divider().overlay(dividerColor)')
text = text.replace('.background(Color.black.opacity(0.12), in:', '.background(listPanelColor, in:')
text = text.replace(
    '.background(Color(red: 11 / 255, green: 31 / 255, blue: 58 / 255), in: Circle())',
    '.background(iconBackground, in: Circle())',
)
old_bg = '''private struct PrayerWidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 9 / 255, green: 25 / 255, blue: 47 / 255),
                Color(red: 15 / 255, green: 44 / 255, blue: 76 / 255),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension View {
    @ViewBuilder
    func munibWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                PrayerWidgetBackground()
            }
        } else {
            background(PrayerWidgetBackground())
        }
    }
}
'''
new_bg = '''private struct PrayerWidgetBackground: View {
    let isDark: Bool

    var body: some View {
        LinearGradient(
            colors: isDark
                ? [
                    Color(red: 7 / 255, green: 20 / 255, blue: 31 / 255),
                    Color(red: 11 / 255, green: 31 / 255, blue: 58 / 255),
                ]
                : [
                    Color(red: 253 / 255, green: 251 / 255, blue: 247 / 255),
                    Color(red: 247 / 255, green: 244 / 255, blue: 238 / 255),
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension View {
    @ViewBuilder
    func munibWidgetBackground(isDark: Bool) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                PrayerWidgetBackground(isDark: isDark)
            }
        } else {
            background(PrayerWidgetBackground(isDark: isDark))
        }
    }
}
'''
if old_bg not in text:
    raise SystemExit('iOS background anchor not found')
text = text.replace(old_bg, new_bg, 1)
ios.write_text(text, encoding='utf-8')

print('Applied startup language/splash and widget theme patch')
