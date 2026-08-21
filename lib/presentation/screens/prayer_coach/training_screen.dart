import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:provider/provider.dart';

import '../../../core/app_strings.dart';
import '../../providers/prayer_coach_provider.dart';
import '../../providers/prayer_provider.dart';

class TrainingScreen extends StatefulWidget {
  final String prayerName;
  const TrainingScreen({super.key, required this.prayerName});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  CameraController? _cameraController;
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );
  final FlutterTts _tts = FlutterTts();

  List<CameraDescription> _cameras = [];
  CameraDescription? _activeCamera;
  bool _isProcessing = false;
  bool _cameraLoading = true;
  String? _cameraError;
  bool _voiceEnabled = true;
  bool _savedCompletion = false;
  int _lastSpokenFeedbackVersion = -1;

  static const _orientations = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _initializeCamera();
  }

  Future<void> _initializeTts() async {
    await _tts.setSpeechRate(0.43);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _initializeCamera({CameraLensDirection? preferred}) async {
    if (mounted) {
      setState(() {
        _cameraLoading = true;
        _cameraError = null;
      });
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw Exception('No camera available');

      final desired = preferred ?? CameraLensDirection.front;
      _activeCamera = _cameras.cast<CameraDescription?>().firstWhere(
        (camera) => camera?.lensDirection == desired,
        orElse: () => _cameras.first,
      );

      await _disposeCamera();
      final controller = CameraController(
        _activeCamera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      _cameraController = controller;
      await controller.initialize();
      await controller.startImageStream(_processCameraImage);

      if (mounted) setState(() => _cameraLoading = false);
    } catch (e) {
      debugPrint('Prayer coach camera init error: $e');
      if (mounted) {
        setState(() {
          _cameraLoading = false;
          _cameraError = e.toString();
        });
      }
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {}
    await controller.dispose();
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _cameraLoading) return;
    final nextDirection = _activeCamera?.lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    await _initializeCamera(preferred: nextDirection);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || !mounted) return;
    _isProcessing = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;
      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty && mounted) {
        context.read<PrayerCoachProvider>().processPose(poses.first);
      }
    } catch (e) {
      debugPrint('Prayer coach pose error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = _cameraController;
    final camera = _activeCamera;
    if (controller == null || camera == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.length != 1) return null;

    final deviceRotation = _orientations[controller.value.deviceOrientation];
    if (deviceRotation == null) return null;

    final rotationCompensation = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + deviceRotation) % 360
        : (camera.sensorOrientation - deviceRotation + 360) % 360;
    final rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    if (rotation == null) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _handleCoachUpdate(PrayerCoachProvider coach) {
    if (coach.feedbackVersion != _lastSpokenFeedbackVersion) {
      _lastSpokenFeedbackVersion = coach.feedbackVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || !_voiceEnabled) return;
        final isEnglish = context.read<PrayerProvider>().isEnglish;
        await _tts.stop();
        await _tts.setLanguage(isEnglish ? 'en-US' : 'ar-SA');
        await _tts.speak(context.tr(coach.feedbackKey));
      });
    }

    if (!coach.isTraining && coach.sessionProgress >= 1 && !_savedCompletion) {
      _savedCompletion = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _saveProgress(coach));
    }
  }

  Future<void> _saveProgress(PrayerCoachProvider coach) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final progressRef = userRef.collection('prayer_coach_progress').doc(widget.prayerName);
      final sessionRef = userRef.collection('training_sessions').doc();
      final now = FieldValue.serverTimestamp();

      final batch = FirebaseFirestore.instance.batch();
      batch.set(
        progressRef,
        {
          'prayer': widget.prayerName,
          'completed_sessions': FieldValue.increment(1),
          'last_progress': 1.0,
          'last_rakah': coach.currentRakah,
          'total_rakahs': coach.totalRakahs,
          'last_completed_at': now,
        },
        SetOptions(merge: true),
      );
      batch.set(sessionRef, {
        'prayer': widget.prayerName,
        'progress': 1.0,
        'rakahs': coach.totalRakahs,
        'completed': true,
        'created_at': now,
      });
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('savedProgress'))),
        );
      }
    } catch (e) {
      debugPrint('Could not save prayer coach progress: $e');
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _disposeCamera();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coach = context.watch<PrayerCoachProvider>();
    _handleCoachUpdate(coach);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraLayer(theme),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: .35),
                  Colors.transparent,
                  theme.scaffoldBackgroundColor.withValues(alpha: .94),
                ],
                stops: const [0, .48, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                children: [
                  _topBar(context, scheme),
                  const Spacer(),
                  _feedbackCard(context, coach),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraLayer(ThemeData theme) {
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_outlined, size: 54, color: theme.colorScheme.primary),
              const SizedBox(height: 18),
              Text(context.tr('cameraError'), textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => _initializeCamera(),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.tr('retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (_cameraLoading || _cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text(context.tr('cameraInitializing'), style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return Center(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize!.height,
            height: _cameraController!.value.previewSize!.width,
            child: CameraPreview(_cameraController!),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, ColorScheme scheme) {
    return Row(
      children: [
        _roundAction(Icons.close_rounded, () {
          context.read<PrayerCoachProvider>().endSession();
          Navigator.pop(context);
        }),
        const SizedBox(width: 10),
        _roundAction(
          _voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          () async {
            setState(() => _voiceEnabled = !_voiceEnabled);
            if (!_voiceEnabled) await _tts.stop();
          },
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: .88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outline),
          ),
          child: Text(widget.prayerName, style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(width: 10),
        _roundAction(Icons.flip_camera_android_rounded, _flipCamera),
      ],
    );
  }

  Widget _roundAction(IconData icon, VoidCallback onPressed) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: .88),
      shape: CircleBorder(side: BorderSide(color: scheme.outline)),
      child: IconButton(onPressed: onPressed, icon: Icon(icon, color: scheme.onSurface)),
    );
  }

  Widget _feedbackCard(BuildContext context, PrayerCoachProvider coach) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percent = (coach.sessionProgress * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.self_improvement_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${context.tr('rakah')} ${coach.currentRakah}/${coach.totalRakahs}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text('$percent%', style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(coach.feedbackKey),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(height: 1.45, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: coach.sessionProgress,
              minHeight: 8,
              backgroundColor: scheme.onSurface.withValues(alpha: .08),
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
