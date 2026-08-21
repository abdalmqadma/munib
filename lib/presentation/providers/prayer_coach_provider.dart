import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../logic/prayer_coach/prayer_state_machine.dart';
import '../../logic/prayer_coach/prayer_rules_engine.dart';

class PrayerCoachProvider with ChangeNotifier {
  late PrayerStateMachine _stateMachine;
  bool _isTraining = false;
  String _feedback = 'يرجى الوقوف أمام الكاميرا للبدء';
  double _sessionProgress = 0.0;
  int _stableFrames = 0;
  PrayerState? _candidateState;
  int _feedbackVersion = 0;

  bool get isTraining => _isTraining;
  String get feedback => _feedback;
  double get sessionProgress => _sessionProgress.clamp(0.0, 1.0);
  PrayerState get currentState => _stateMachine.currentState;
  int get currentRakah => _stateMachine.currentRakah;
  int get totalRakahs => _stateMachine.totalRakahs;
  int get feedbackVersion => _feedbackVersion;

  void startSession(int rakahs) {
    _stateMachine = PrayerStateMachine(totalRakahs: rakahs);
    _isTraining = true;
    _sessionProgress = 0;
    _stableFrames = 0;
    _candidateState = null;
    _setFeedback('استعد، قف باعتدال بحيث يظهر جسمك كاملًا');
  }

  void processPose(Pose pose) {
    if (!_isTraining) return;

    if (!PrayerRulesEngine.hasEnoughLandmarks(pose)) {
      _stableFrames = 0;
      _candidateState = null;
      _setFeedback('ابتعد قليلًا حتى يظهر جسمك كاملًا أمام الكاميرا', notify: true);
      return;
    }

    final target = _detectExpectedState(pose);
    if (target == null) {
      _stableFrames = 0;
      _candidateState = null;
      return;
    }

    if (_candidateState == target) {
      _stableFrames++;
    } else {
      _candidateState = target;
      _stableFrames = 1;
    }

    // Require several consecutive frames to avoid accidental transitions.
    if (_stableFrames < 4) return;

    if (_stateMachine.transition(target)) {
      _stableFrames = 0;
      _candidateState = null;
      _updateProgressAndFeedback();
    }
  }

  PrayerState? _detectExpectedState(Pose pose) {
    switch (_stateMachine.currentState) {
      case PrayerState.idle:
        return PrayerRulesEngine.isStanding(pose) ? PrayerState.standing : null;
      case PrayerState.standing:
        return PrayerRulesEngine.isRuku(pose) ? PrayerState.ruku : null;
      case PrayerState.ruku:
        return PrayerRulesEngine.isStanding(pose) ? PrayerState.standingAfterRuku : null;
      case PrayerState.standingAfterRuku:
        return PrayerRulesEngine.isSujud(pose) ? PrayerState.sujud1 : null;
      case PrayerState.sujud1:
        return PrayerRulesEngine.isSitting(pose) ? PrayerState.sitting : null;
      case PrayerState.sitting:
        return PrayerRulesEngine.isSujud(pose) ? PrayerState.sujud2 : null;
      case PrayerState.sujud2:
        if (_stateMachine.currentRakah < _stateMachine.totalRakahs) {
          return PrayerRulesEngine.isStanding(pose) ? PrayerState.standing : null;
        }
        // Final rak'ah completes after a stable second sujud.
        return PrayerRulesEngine.isSujud(pose) ? PrayerState.completed : null;
      case PrayerState.completed:
        return null;
    }
  }

  void _updateProgressAndFeedback() {
    const stepsPerRakah = 6;
    final completedRakahs = _stateMachine.currentRakah - 1;
    final stateStep = switch (_stateMachine.currentState) {
      PrayerState.idle => 0,
      PrayerState.standing => 1,
      PrayerState.ruku => 2,
      PrayerState.standingAfterRuku => 3,
      PrayerState.sujud1 => 4,
      PrayerState.sitting => 5,
      PrayerState.sujud2 => 6,
      PrayerState.completed => stepsPerRakah,
    };

    _sessionProgress =
        (completedRakahs * stepsPerRakah + stateStep) /
        (_stateMachine.totalRakahs * stepsPerRakah);

    switch (_stateMachine.currentState) {
      case PrayerState.standing:
        _setFeedback('ممتاز، الآن اركع بهدوء');
        break;
      case PrayerState.ruku:
        _setFeedback('ركوع جيد، ارفع حتى تعود واقفًا');
        break;
      case PrayerState.standingAfterRuku:
        _setFeedback('أحسنت، انزل الآن للسجود');
        break;
      case PrayerState.sujud1:
        _setFeedback('سجود جيد، اجلس بين السجدتين');
        break;
      case PrayerState.sitting:
        _setFeedback('اجلس باعتدال، ثم اسجد مرة ثانية');
        break;
      case PrayerState.sujud2:
        _setFeedback(
          _stateMachine.currentRakah < _stateMachine.totalRakahs
              ? 'أحسنت، قم للركعة التالية'
              : 'ثبت في السجود لحظة لإكمال الصلاة',
        );
        break;
      case PrayerState.completed:
        _sessionProgress = 1;
        _isTraining = false;
        _setFeedback('تقبل الله، اكتملت جلسة التدريب');
        break;
      case PrayerState.idle:
        break;
    }
    notifyListeners();
  }

  void _setFeedback(String value, {bool notify = false}) {
    if (_feedback == value) {
      if (notify) notifyListeners();
      return;
    }
    _feedback = value;
    _feedbackVersion++;
    notifyListeners();
  }

  void endSession() {
    _isTraining = false;
    notifyListeners();
  }
}
