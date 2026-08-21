import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_strings.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/ocr_service.dart';
import 'review_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isLoading = false;
  bool _hasError = false;
  int _loadingStep = 0;

  final OCRService _ocrService = OCRService();
  final AIService _aiService = AIService();

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final path = result?.files.single.path;
    if (path != null) await _processFile(XFile(path));
  }

  Future<void> _processImage(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (image != null) await _processFile(image);
  }

  Future<void> _processFile(XFile file) async {
    setState(() {
      _hasError = false;
      _isLoading = true;
      _loadingStep = 1;
    });

    try {
      File fileToProcess = File(file.path);
      if (!file.path.toLowerCase().endsWith('.pdf')) {
        fileToProcess = await _compressImageIfNeeded(fileToProcess);
      }

      if (mounted) setState(() => _loadingStep = 2);
      List<Map<String, dynamic>> structuredData;

      if (file.path.toLowerCase().endsWith('.pdf')) {
        final text = await _ocrService.extractText(XFile(fileToProcess.path));
        if (mounted) setState(() => _loadingStep = 3);
        structuredData = await _aiService.structurePrayerTimes(text);
      } else {
        if (mounted) setState(() => _loadingStep = 3);
        structuredData = await _aiService.structurePrayerTimesFromImage(fileToProcess);
      }

      if (mounted) setState(() => _loadingStep = 4);

      if (!mounted) return;
      if (structuredData.isEmpty) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ReviewScreen(initialData: structuredData)),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } finally {
      if (mounted && !_hasError) setState(() => _isLoading = false);
    }
  }

  Future<File> _compressImageIfNeeded(File original) async {
    final sizeInBytes = await original.length();
    const maxAllowedBytes = 3 * 1024 * 1024;
    if (sizeInBytes <= maxAllowedBytes) return original;

    final bytes = await original.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return original;

    img.Image resized = decoded;
    if (decoded.width > 1600 || decoded.height > 1600) {
      resized = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? 1600 : null,
        height: decoded.height > decoded.width ? 1600 : null,
      );
    }

    int quality = 85;
    List<int> output = img.encodeJpg(resized, quality: quality);
    while (output.length > maxAllowedBytes && quality > 30) {
      quality -= 10;
      output = img.encodeJpg(resized, quality: quality);
    }

    final tempDir = await getTemporaryDirectory();
    final compressed = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await compressed.writeAsBytes(output);
    return compressed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isLoading ? null : AppBar(title: Text(context.tr('uploadTitle'))),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _hasError
              ? _ErrorState(onRetry: () => setState(() => _hasError = false))
              : _isLoading
                  ? _LoadingState(step: _loadingStep)
                  : _UploadContent(
                      onFile: _pickFile,
                      onGallery: () => _processImage(ImageSource.gallery),
                      onCamera: () => _processImage(ImageSource.camera),
                    ),
        ),
      ),
    );
  }
}

class _UploadContent extends StatelessWidget {
  final VoidCallback onFile;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  const _UploadContent({required this.onFile, required this.onGallery, required this.onCamera});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
      children: [
        Text(context.tr('uploadHint'), style: theme.textTheme.bodyLarge),
        const SizedBox(height: 24),
        InkWell(
          onTap: onFile,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            height: 230,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.45), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined, size: 58, color: scheme.primary),
                const SizedBox(height: 16),
                Text(context.tr('file'), style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('JPG • PNG • PDF', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.photo_library_outlined,
                title: context.tr('gallery'),
                onTap: onGallery,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.camera_alt_outlined,
                title: context.tr('camera'),
                onTap: onCamera,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          children: [
            Icon(icon, color: scheme.primary, size: 30),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final int step;

  const _LoadingState({required this.step});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = [
      context.tr('processing1'),
      context.tr('processing2'),
      context.tr('processing3'),
      context.tr('processing4'),
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 52, color: scheme.primary),
            ),
            const SizedBox(height: 24),
            Text(context.tr('processing'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 28),
            ...List.generate(labels.length, (index) {
              final number = index + 1;
              final done = step > number;
              final current = step == number;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: done
                    ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                    : current
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Icon(Icons.circle_outlined, color: scheme.outline),
                title: Text(labels[index]),
              );
            }),
            const SizedBox(height: 18),
            LinearProgressIndicator(value: step.clamp(0, 4) / 4),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 72, color: scheme.error),
            const SizedBox(height: 20),
            Text(
              context.tr('processingError'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('tryAgain')),
            ),
          ],
        ),
      ),
    );
  }
}
