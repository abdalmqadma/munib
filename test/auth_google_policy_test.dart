import 'package:flutter_test/flutter_test.dart';
import 'package:munib/features/auth/data/auth_service.dart';

void main() {
  group('Google sign-in legal consent', () {
    test('rejects only a brand-new Google account without consent', () {
      expect(
        AuthService.shouldRejectNewGoogleAccount(
          isNewUser: true,
          acceptedLegal: false,
        ),
        isTrue,
      );
    });

    test('allows a new Google account after consent', () {
      expect(
        AuthService.shouldRejectNewGoogleAccount(
          isNewUser: true,
          acceptedLegal: true,
        ),
        isFalse,
      );
    });

    test('does not require consent again for an existing Google account', () {
      expect(
        AuthService.shouldRejectNewGoogleAccount(
          isNewUser: false,
          acceptedLegal: false,
        ),
        isFalse,
      );
    });
  });
}
