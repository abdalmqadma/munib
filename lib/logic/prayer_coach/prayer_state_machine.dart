enum PrayerState {
  idle,
  standing,
  ruku,
  standingAfterRuku,
  sujud1,
  sitting,
  sujud2,
  completed
}

class PrayerStateMachine {
  PrayerState _currentState = PrayerState.idle;
  int _currentRakah = 1;
  final int totalRakahs;

  PrayerStateMachine({required this.totalRakahs});

  PrayerState get currentState => _currentState;
  int get currentRakah => _currentRakah;

  // منطق الانتقال بين الحالات
  bool transition(PrayerState nextState) {
    switch (_currentState) {
      case PrayerState.idle:
        if (nextState == PrayerState.standing) {
          _currentState = nextState;
          return true;
        }
        break;
      case PrayerState.standing:
        if (nextState == PrayerState.ruku) {
          _currentState = nextState;
          return true;
        }
        break;
      case PrayerState.ruku:
        if (nextState == PrayerState.standingAfterRuku) {
          _currentState = nextState;
          return true;
        }
        break;
      case PrayerState.standingAfterRuku:
        if (nextState == PrayerState.sujud1) {
          _currentState = nextState;
          return true;
        }
        break;
      case PrayerState.sujud1:
        if (nextState == PrayerState.sitting) {
          _currentState = nextState;
          return true;
        }
        break;
      case PrayerState.sitting:
        if (nextState == PrayerState.sujud2) {
          _currentState = nextState;
          return true;
        }
        break;
      case PrayerState.sujud2:
        if (_currentRakah < totalRakahs) {
          if (nextState == PrayerState.standing) {
            _currentRakah++;
            _currentState = PrayerState.standing;
            return true;
          }
        } else {
          _currentState = PrayerState.completed;
          return true;
        }
        break;
      case PrayerState.completed:
        return false;
    }
    return false;
  }

  void reset() {
    _currentState = PrayerState.idle;
    _currentRakah = 1;
  }
}
