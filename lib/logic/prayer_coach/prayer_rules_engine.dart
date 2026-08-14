import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum PrayerMovement {
  standing,
  takbir,
  ruku,
  sujud,
  sitting,
  none
}

class PrayerRulesEngine {
  // تتبع زاوية المفصل لتقييم الحركة
  static double calculateAngle(PoseLandmark first, PoseLandmark middle, PoseLandmark last) {
    double radians = math.atan2(last.y - middle.y, last.x - middle.x) -
                     math.atan2(first.y - middle.y, first.x - middle.x);
    double angle = (radians * 180 / math.pi).abs();
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  // التحقق من وضعية الوقوف (الاعتدال)
  static bool isStanding(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    if (leftShoulder == null || leftAnkle == null) return false;
    
    // يجب أن يكون الكتف فوق الكاحل تقريباً (فرق x بسيط)
    return (leftShoulder.x - leftAnkle.x).abs() < 50;
  }

  // التحقق من الركوع (زاوية الظهر)
  static bool isRuku(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    
    if (shoulder == null || hip == null || knee == null) return false;
    
    double angle = calculateAngle(shoulder, hip, knee);
    // زاوية الركوع المثالية حول 90 درجة
    return angle > 70 && angle < 110;
  }

  // التحقق من السجود (انخفاض الرأس بالنسبة للورك)
  static bool isSujud(Pose pose) {
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    if (nose == null || hip == null) return false;
    
    // في السجود يكون الأنف أخفض بكثير من الورك
    return nose.y > hip.y + 100;
  }
}
