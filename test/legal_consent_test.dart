import 'package:flutter_test/flutter_test.dart';
import 'package:munib/core/legal_consent.dart';

void main() {
  group('legal consent gate', () {
    test('login does not require signup consent', () {
      expect(
        canSubmitAuthAction(isLogin: true, acceptedLegal: false),
        isTrue,
      );
    });

    test('signup is blocked without consent', () {
      expect(
        canSubmitAuthAction(isLogin: false, acceptedLegal: false),
        isFalse,
      );
    });

    test('signup is allowed after consent', () {
      expect(
        canSubmitAuthAction(isLogin: false, acceptedLegal: true),
        isTrue,
      );
    });
  });
}
