import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../logic/prayer_coach/prayer_state_machine.dart';
import '../../logic/prayer_coach/prayer_rules_engine.dart';

class PrayerCoachProvider with ChangeNotifier {
  late PrayerStateMachine _stateMachine;
  bool _isTraining = false;
  String _feedbackKey = 'coachReady';
  double _sessionProgress = 0.0;
  int _stableFrames = 0;
  PrayerState? _candidateState;
  int _feedbackVersion = 0;

  bool get isTraining => _isTraining;
  String get feedbackKey => _feedbackKey;
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
    _setFeedbackKey('coachReady');
  }

  void processPose(Pose pose) {
    if (!_isTraining) return;

    if (!PrayerRulesEngine.hasEnoughLandmarks(pose)) {
      _stableFrames = 0;
      _candidateState = null;
      _setFeedbackKey('coachBodyVisible');
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

    _sessionProgress = (completedRakahs * stepsPerRakah + stateStep) /
        (_stateMachine.totalRakahs * stepsPerRakah);

    switch (_stateMachine.currentState) {
      case PrayerState.standing:
        _setFeedbackKey('coachToRuku');
        break;
      case PrayerState.ruku:
        _setFeedbackKey('coachRise');
        break;
      case PrayerState.standingAfterRuku:
        _setFeedbackKey('coachToSujud');
        break;
      case PrayerState.sujud1:
        _setFeedbackKey('coachToSit');
        break;
      case PrayerState.sitting:
        _setFeedbackKey('coachSecondSujud');
        break;
      case PrayerState.sujud2:
        _setFeedbackKey(
          _stateMachine.currentRakah < _stateMachine.totalRakahs
              ? 'coachNextRakah'
              : 'coachHoldSujud',
        );
        break;
      case PrayerState.completed:
        _sessionProgress = 1;
        _isTraining = false;
        _setFeedbackKey('coachDone');
        break;
      case PrayerState.idle:
        break;
    }
    notifyListeners();
  }

  void _setFeedbackKey(String value) {
    if (_feedbackKey == value) return;
    _feedbackKey = value;
    _feedbackVersion++;
    notifyListeners();
  }

  void endSession() {
    _isTraining = false;
    notifyListeners();
  }
}
