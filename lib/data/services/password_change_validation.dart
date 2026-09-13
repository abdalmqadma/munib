const int minimumMunibPasswordLength = 6;

String? validatePasswordChange({
  required String currentPassword,
  required String newPassword,
  required String confirmation,
}) {
  if (currentPassword.isEmpty) return 'current-required';
  if (newPassword.length < minimumMunibPasswordLength) {
    return 'new-too-short';
  }
  if (newPassword == currentPassword) return 'same-password';
  if (confirmation != newPassword) return 'confirmation-mismatch';
  return null;
}
