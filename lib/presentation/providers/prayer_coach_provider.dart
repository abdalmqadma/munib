import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../logic/prayer_coach/prayer_state_machine.dart';
import '../../logic/prayer_coach/prayer_rules_engine.dart';

class PrayerCoachProvider with ChangeNotifier {
  late PrayerStateMachine _stateMachine;
  bool _isTraining = false;
  String _feedback = "يرجى الوقوف أمام الكاميرا للبدء";
  double _sessionProgress = 0.0;
  
  bool get isTraining => _isTraining;
  String get feedback => _feedback;
  double get sessionProgress => _sessionProgress;
  PrayerState get currentState => _stateMachine.currentState;
  int get currentRakah => _stateMachine.currentRakah;

  void startSession(int rakahs) {
    _stateMachine = PrayerStateMachine(totalRakahs: rakahs);
    _isTraining = true;
    _feedback = "استعد، ابدأ بالوقوف باعتدال";
    notifyListeners();
  }

  void processPose(Pose pose) {
    if (!_isTraining) return;

    // منطق التحقق من الحركات بناءً على الحالة الحالية
    switch (_stateMachine.currentState) {
      case PrayerState.idle:
      case PrayerState.standingAfterRuku:
        if (PrayerRulesEngine.isStanding(pose)) {
          bool success = _stateMachine.transition(
            _stateMachine.currentState == PrayerState.idle ? PrayerState.standing : PrayerState.sujud1
          );
          if (success) _updateFeedback();
        }
        break;
      case PrayerState.standing:
        if (PrayerRulesEngine.isRuku(pose)) {
          if (_stateMachine.transition(PrayerState.ruku)) _updateFeedback();
        }
        break;
      case PrayerState.ruku:
        if (PrayerRulesEngine.isStanding(pose)) {
          if (_stateMachine.transition(PrayerState.standingAfterRuku)) _updateFeedback();
        }
        break;
      case PrayerState.sujud1:
        if (PrayerRulesEngine.isSujud(pose)) { // Simplified for demo
           _stateMachine.transition(PrayerState.sitting);
           _updateFeedback();
        }
        break;
      // سيتم إكمال باقي الحالات لاحقاً
      default:
        break;
    }
    notifyListeners();
  }

  void _updateFeedback() {
    final totalSteps = 7 * _stateMachine.totalRakahs; // rough estimate of steps
    _sessionProgress = (_stateMachine.currentRakah - 1) / _stateMachine.totalRakahs + 
                       (_stateMachine.currentState.index / 8 / _stateMachine.totalRakahs);

    switch (_stateMachine.currentState) {
      case PrayerState.standing: _feedback = "ممتاز، الآن اركع بهدوء"; break;
      case PrayerState.ruku: _feedback = "وضعية ركوع جيدة، ارفع رأسك"; break;
      case PrayerState.standingAfterRuku: _feedback = "استعد للسجود"; break;
      case PrayerState.sujud1: _feedback = "سجود صحيح، اجلس الآن"; break;
      case PrayerState.sitting: _feedback = "اجلس باعتدال، ثم اسجد مرة أخرى"; break;
      case PrayerState.sujud2: _feedback = "سجود ثانٍ صحيح"; break;
      case PrayerState.completed: 
        _feedback = "تقبل الله، انتهت الصلاة"; 
        _sessionProgress = 1.0;
        _isTraining = false; 
        break;
      default: break;
    }
  }

  void endSession() {
    _isTraining = false;
    notifyListeners();
  }
}
