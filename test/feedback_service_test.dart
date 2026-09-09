import 'package:flutter_test/flutter_test.dart';
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
