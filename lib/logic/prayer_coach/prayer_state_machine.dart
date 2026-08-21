enum PrayerState {
  idle,
  standing,
  ruku,
  standingAfterRuku,
  sujud1,
  sitting,
  sujud2,
  completed,
}

class PrayerStateMachine {
  PrayerState _currentState = PrayerState.idle;
  int _currentRakah = 1;
  final int totalRakahs;

  PrayerStateMachine({required int totalRakahs}) : totalRakahs = totalRakahs < 1 ? 1 : totalRakahs;

  PrayerState get currentState => _currentState;
  int get currentRakah => _currentRakah;

  bool transition(PrayerState nextState) {
    if (_currentState == PrayerState.completed) return false;

    final expected = switch (_currentState) {
      PrayerState.idle => PrayerState.standing,
      PrayerState.standing => PrayerState.ruku,
      PrayerState.ruku => PrayerState.standingAfterRuku,
      PrayerState.standingAfterRuku => PrayerState.sujud1,
      PrayerState.sujud1 => PrayerState.sitting,
      PrayerState.sitting => PrayerState.sujud2,
      PrayerState.sujud2 => _currentRakah < totalRakahs ? PrayerState.standing : PrayerState.completed,
      PrayerState.completed => PrayerState.completed,
    };

    if (nextState != expected) return false;

    if (_currentState == PrayerState.sujud2 && nextState == PrayerState.standing) {
      _currentRakah++;
    }
    _currentState = nextState;
    return true;
  }

  void reset() {
    _currentState = PrayerState.idle;
    _currentRakah = 1;
  }
}
