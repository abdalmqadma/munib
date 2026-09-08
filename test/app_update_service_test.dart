import 'package:flutter_test/flutter_test.dart';
import 'package:munib/data/services/app_update_service.dart';

void main() {
  group('evaluateAppUpdate', () {
    test('returns none when current build is latest', () {
      expect(
        evaluateAppUpdate(
          currentBuild: 5,
          latestBuild: 5,
          minimumBuild: 3,
        ),
        AppUpdateType.none,
      );
    });

    test('returns optional when a newer build exists but current is supported', () {
      expect(
        evaluateAppUpdate(
          currentBuild: 4,
          latestBuild: 5,
          minimumBuild: 3,
        ),
        AppUpdateType.optional,
      );
    });

    test('returns force when current build is below minimum', () {
      expect(
        evaluateAppUpdate(
          currentBuild: 2,
          latestBuild: 5,
          minimumBuild: 3,
        ),
        AppUpdateType.force,
      );
    });

    test('minimum build also acts as latest when remote values are inconsistent', () {
      expect(
        evaluateAppUpdate(
          currentBuild: 4,
          latestBuild: 3,
          minimumBuild: 5,
        ),
        AppUpdateType.force,
      );
    });

    test('invalid current build never forces an update', () {
      expect(
        evaluateAppUpdate(
          currentBuild: 0,
          latestBuild: 9,
          minimumBuild: 9,
        ),
        AppUpdateType.none,
      );
    });
  });
}
