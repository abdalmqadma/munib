class PushDestination {
  final int homeIndex;
  final String initialAzkarCategory;

  const PushDestination({
    required this.homeIndex,
    this.initialAzkarCategory = 'Morning',
  });
}

class PushNavigationService {
  const PushNavigationService._();

  static PushDestination? _pendingDestination;

  static PushDestination? destinationFromData(Map<String, dynamic> data) {
    final rawTarget = (data['screen'] ?? data['target'] ?? data['route'])
        ?.toString()
        .trim()
        .toLowerCase();

    if (rawTarget == null || rawTarget.isEmpty) return null;

    switch (rawTarget) {
      case 'home':
      case 'prayer':
      case 'prayers':
      case 'prayer_times':
      case 'prayer-times':
      case 'prayer_times_view':
        return const PushDestination(homeIndex: 0);
      case 'adhkar':
      case 'azkar':
      case 'adhkar_view':
        return PushDestination(
          homeIndex: 1,
          initialAzkarCategory: _normalizedAzkarCategory(
            data['category'] ?? data['adhkar_category'],
          ),
        );
      case 'nafahat':
      case 'nafahat_view':
        return const PushDestination(homeIndex: 2);
      case 'settings':
        return const PushDestination(homeIndex: 3);
      default:
        return null;
    }
  }

  static void defer(PushDestination destination) {
    _pendingDestination = destination;
  }

  static PushDestination? takePending() {
    final destination = _pendingDestination;
    _pendingDestination = null;
    return destination;
  }

  static String _normalizedAzkarCategory(Object? raw) {
    final category = raw?.toString().trim().toLowerCase();
    return switch (category) {
      'evening' || 'مساء' || 'المساء' => 'Evening',
      _ => 'Morning',
    };
  }
}
