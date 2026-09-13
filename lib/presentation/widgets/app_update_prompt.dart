import 'package:flutter/material.dart';

import '../../data/services/app_update_service.dart';

class AppUpdateNavigatorObserver extends NavigatorObserver {
  void _checkRoute(Route<dynamic>? route) {
    if (route?.settings.name != '/home') return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentNavigator = navigator;
      if (currentNavigator == null || !currentNavigator.mounted) return;
      AppUpdatePrompt.showIfNeeded(currentNavigator.context);
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _checkRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _checkRoute(newRoute);
  }
}

class AppUpdatePrompt {
  const AppUpdatePrompt._();

  static Future<void> showIfNeeded(BuildContext context) async {
    final decision = await AppUpdateService.checkForUpdate();
    if (!context.mounted || !decision.shouldShow) return;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    await showDialog<void>(
      context: context,
      barrierDismissible: !decision.isForce,
      builder: (dialogContext) => PopScope(
        canPop: !decision.isForce,
        child: AlertDialog(
          icon: Icon(
            decision.isForce
                ? Icons.system_update_alt_rounded
                : Icons.new_releases_outlined,
          ),
          title: Text(
            decision.isForce
                ? (isArabic ? 'تحديث مطلوب' : 'Update required')
                : (isArabic ? 'تحديث جديد متوفر' : 'New update available'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(decision.message),
              const SizedBox(height: 14),
              Text(
                isArabic
                    ? 'الإصدار المثبت: ${decision.currentBuild}  •  الأحدث: ${decision.latestBuild}'
                    : 'Installed build: ${decision.currentBuild}  •  Latest: ${decision.latestBuild}',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            if (!decision.isForce)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(isArabic ? 'لاحقًا' : 'Later'),
              ),
            FilledButton.icon(
              onPressed: () async {
                final opened =
                    await AppUpdateService.openUpdateUrl(decision.updateUrl);
                if (!context.mounted || !dialogContext.mounted) return;

                if (!opened) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isArabic
                            ? 'تعذر فتح رابط التحديث. حاول مرة أخرى.'
                            : 'Could not open the update link. Please try again.',
                      ),
                    ),
                  );
                  return;
                }

                if (!decision.isForce) {
                  Navigator.of(dialogContext).pop();
                }
              },
              icon: const Icon(Icons.download_rounded),
              label: Text(isArabic ? 'تحديث الآن' : 'Update now'),
            ),
          ],
        ),
      ),
    );
  }
}
