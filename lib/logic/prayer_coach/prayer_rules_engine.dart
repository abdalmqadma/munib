import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum PrayerMovement { standing, ruku, sujud, sitting, none }

class PrayerRulesEngine {
  static const double _minLikelihood = 0.45;

  static double calculateAngle(PoseLandmark first, PoseLandmark middle, PoseLandmark last) {
    var radians = math.atan2(last.y - middle.y, last.x - middle.x) -
        math.atan2(first.y - middle.y, first.x - middle.x);
    var angle = (radians * 180 / math.pi).abs();
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  static bool _visible(PoseLandmark? p) => p != null && p.likelihood >= _minLikelihood;

  static double _distance(PoseLandmark a, PoseLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  static double? _bodyScale(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];
    if (!_visible(shoulder) || !_visible(ankle)) return null;
    final scale = _distance(shoulder!, ankle!);
    return scale > 20 ? scale : null;
  }

  static bool hasEnoughLandmarks(Pose pose) {
    final types = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];
    return types.where((t) => _visible(pose.landmarks[t])).length >= 7;
  }

  static bool isStanding(Pose pose) {
    if (!hasEnoughLandmarks(pose)) return false;
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];
    if (!_visible(shoulder) || !_visible(hip) || !_visible(knee) || !_visible(ankle)) return false;

    final hipAngle = calculateAngle(shoulder!, hip!, knee!);
    final kneeAngle = calculateAngle(hip, knee, ankle!);
    final scale = _bodyScale(pose)!;
    final verticalAlignment = (shoulder.x - ankle.x).abs() / scale;
    return hipAngle > 155 && kneeAngle > 155 && verticalAlignment < 0.22;
  }

  static bool isRuku(Pose pose) {
    if (!hasEnoughLandmarks(pose)) return false;
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];
    if (!_visible(shoulder) || !_visible(hip) || !_visible(knee) || !_visible(ankle)) return false;

    final hipAngle = calculateAngle(shoulder!, hip!, knee!);
    final kneeAngle = calculateAngle(hip, knee, ankle!);
    final torsoSlope = ((shoulder.y - hip.y).abs()) / ((shoulder.x - hip.x).abs() + 1);
    return hipAngle >= 65 && hipAngle <= 120 && kneeAngle > 135 && torsoSlope < 1.25;
  }

  static bool isSujud(Pose pose) {
    if (!hasEnoughLandmarks(pose)) return false;
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    final scale = _bodyScale(pose);
    if (!_visible(nose) || !_visible(shoulder) || !_visible(hip) || !_visible(knee) || scale == null) return false;

    final headLow = nose!.y > hip!.y - scale * 0.08;
    final torsoLow = shoulder!.y > hip.y - scale * 0.18;
    final hipNearKnee = (hip.y - knee!.y).abs() < scale * 0.38;
    return headLow && torsoLow && hipNearKnee;
  }

  static bool isSitting(Pose pose) {
    if (!hasEnoughLandmarks(pose)) return false;
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];
    if (!_visible(shoulder) || !_visible(hip) || !_visible(knee) || !_visible(ankle)) return false;

    final hipAngle = calculateAngle(shoulder!, hip!, knee!);
    final kneeAngle = calculateAngle(hip, knee, ankle!);
    return hipAngle > 70 && hipAngle < 125 && kneeAngle < 135;
  }
}
