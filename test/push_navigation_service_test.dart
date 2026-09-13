import 'package:flutter_test/flutter_test.dart';
import 'package:munib/data/services/push_navigation_service.dart';

void main() {
  group('PushNavigationService.destinationFromData', () {
    test('routes prayer targets to home', () {
      final destination = PushNavigationService.destinationFromData(
        {'screen': 'prayer_times'},
      );

      expect(destination, isNotNull);
      expect(destination!.homeIndex, 0);
    });

    test('routes adhkar with normalized evening category', () {
      final destination = PushNavigationService.destinationFromData(
        {'screen': 'adhkar', 'category': 'evening'},
      );

      expect(destination, isNotNull);
      expect(destination!.homeIndex, 1);
      expect(destination.initialAzkarCategory, 'Evening');
    });

    test('routes Nafahat and settings to their tabs', () {
      expect(
        PushNavigationService.destinationFromData(
          {'target': 'nafahat'},
        )?.homeIndex,
        2,
      );
      expect(
        PushNavigationService.destinationFromData(
          {'route': 'settings'},
        )?.homeIndex,
        3,
      );
    });

    test('ignores unsupported destinations', () {
      expect(
        PushNavigationService.destinationFromData(
          {'screen': 'unknown-screen'},
        ),
        isNull,
      );
    });
  });

  test('deferred destination is consumed once', () {
    const destination = PushDestination(
      homeIndex: 1,
      initialAzkarCategory: 'Morning',
    );

    PushNavigationService.defer(destination);

    expect(PushNavigationService.takePending(), same(destination));
    expect(PushNavigationService.takePending(), isNull);
  });
}
