import 'package:flutter_test/flutter_test.dart';
import 'package:munib/data/services/password_change_validation.dart';

void main() {
  group('validatePasswordChange', () {
    test('requires the current password', () {
      expect(
        validatePasswordChange(
          currentPassword: '',
          newPassword: 'abcdef',
          confirmation: 'abcdef',
        ),
        'current-required',
      );
    });

    test('rejects a short new password', () {
      expect(
        validatePasswordChange(
          currentPassword: 'oldpass',
          newPassword: '12345',
          confirmation: '12345',
        ),
        'new-too-short',
      );
    });

    test('rejects reusing the current password', () {
      expect(
        validatePasswordChange(
          currentPassword: 'samepass',
          newPassword: 'samepass',
          confirmation: 'samepass',
        ),
        'same-password',
      );
    });

    test('requires matching confirmation', () {
      expect(
        validatePasswordChange(
          currentPassword: 'oldpass',
          newPassword: 'newpass1',
          confirmation: 'newpass2',
        ),
        'confirmation-mismatch',
      );
    });

    test('accepts a valid password change form', () {
      expect(
        validatePasswordChange(
          currentPassword: 'oldpass',
          newPassword: 'newpass1',
          confirmation: 'newpass1',
        ),
        isNull,
      );
    });
  });
}
