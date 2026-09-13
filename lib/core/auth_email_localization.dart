String normalizeAuthEmailLanguage(String languageCode) {
  final normalized = languageCode.trim().toLowerCase();
  if (normalized.startsWith('ar')) return 'ar';
  return 'en';
}
