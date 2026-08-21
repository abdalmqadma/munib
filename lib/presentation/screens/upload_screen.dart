import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  int _loadingStep = 0;
  bool _hasError = false;
  final OCRService _ocrService = OCRService();
  final AIService _aiService = AIService();

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    final path = result?.files.single.path;
    if (path != null) {
      await _processFile(XFile(path));
    }
  }

  Future<void> _processImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 100,
    );
    if (image != null) {
      await _processFile(image);
    }
  }

  Future<void> _processFile(XFile file) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _loadingStep = 1;
    });

    try {
      final inputFile = File(file.path);
      final isPdf = file.path.toLowerCase().endsWith('.pdf');
      final fileSize = await inputFile.length();
      debugPrint('[MUNIB] Processing started: ${file.path}');
      debugPrint('[MUNIB] Input type: ${isPdf ? 'PDF' : 'IMAGE'}, bytes: $fileSize');

      setState(() => _loadingStep = 2);
      debugPrint('[MUNIB] OCR START');
      final ocrWatch = Stopwatch()..start();

      final rawOcrText = await (isPdf
              ? _ocrService.extractTextFromPdf(inputFile)
              : _ocrService.extractText(file))
          .timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw TimeoutException('OCR timed out after 90 seconds'),
      );

      ocrWatch.stop();
      debugPrint('[MUNIB] OCR FINISHED in ${ocrWatch.elapsedMilliseconds} ms');
      debugPrint('[MUNIB] OCR characters: ${rawOcrText.length}');
      final preview = rawOcrText.replaceAll(RegExp(r'\s+'), ' ').trim();
      debugPrint('[MUNIB] OCR preview: ${preview.length > 500 ? preview.substring(0, 500) : preview}');

      if (rawOcrText.trim().isEmpty) {
        throw Exception('OCR returned no text');
      }

      setState(() => _loadingStep = 3);
      debugPrint('[MUNIB] AI START');
      final aiWatch = Stopwatch()..start();
      final structuredData = await _aiService
          .structurePrayerTimes(rawOcrText)
          .timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('AI request timed out after 60 seconds'),
      );
      aiWatch.stop();
      debugPrint('[MUNIB] AI FINISHED in ${aiWatch.elapsedMilliseconds} ms');
      debugPrint('[MUNIB] AI returned ${structuredData.length} prayer day(s)');

      setState(() => _loadingStep = 4);
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      if (structuredData.isEmpty) {
        debugPrint('[MUNIB] Processing failed: AI returned an empty prayer-day list');
        _showErrorUI();
        return;
      }

      debugPrint('[MUNIB] Processing successful; opening review screen');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewScreen(initialData: structuredData),
        ),
      );
    } on TimeoutException catch (e) {
      debugPrint('[MUNIB] TIMEOUT: $e');
      if (mounted) _showErrorUI();
    } catch (e, stackTrace) {
      debugPrint('[MUNIB] Imsakia processing failed: $e');
      debugPrint('[MUNIB] Stack trace: $stackTrace');
      if (mounted) _showErrorUI();
    } finally {
      if (mounted && !_hasError) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorUI() {
    setState(() {
      _hasError = true;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071019),
      body: SafeArea(
        child: _hasError
            ? _buildErrorContent()
            : (_isLoading ? _buildLoading() : _buildContent()),
      ),
    );
  }

  Widget _buildErrorContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent.withOpacity(0.1), width: 2),
                  ),
                ),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withOpacity(0.05),
                  ),
                  child: const Icon(Icons.priority_high_rounded, size: 45, color: Colors.redAccent),
                ),
              ],
            ),
            const SizedBox(height: 50),
            const Text(
              'تعذّر قراءة الإمساكية',
              style: TextStyle(color: Colors.redAccent, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'تعذر استخراج بيانات كافية. حاول بصورة أوضح مع إضاءة جيدة',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: 220,
              height: 60,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _hasError = false),
                icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent),
                label: const Text('حاول مرة أخرى', style: TextStyle(color: Colors.redAccent, fontSize: 18)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue.withOpacity(0.2), width: 2),
                gradient: RadialGradient(
                  colors: [Colors.blue.withOpacity(0.1), Colors.transparent],
                ),
              ),
              child: const Center(
                child: Icon(Icons.smart_toy_rounded, size: 80, color: Colors.blueAccent),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'منيب يقرأ الإمساكية',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'جاري استخراج أوقات الصلاة...',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
            const SizedBox(height: 50),
            _buildLoadingStep(1, 'قراءة الصورة', _loadingStep),
            _buildLoadingStep(2, 'استخراج النص العربي', _loadingStep),
            _buildLoadingStep(3, 'فهم الجدول وتحليله', _loadingStep),
            _buildLoadingStep(4, 'تجهيز أوقات الصلاة', _loadingStep),
            const SizedBox(height: 50),
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _loadingStep / 4,
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  '${(_loadingStep / 4 * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white24, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingStep(int step, String title, int currentStep) {
    final isDone = currentStep > step;
    final isCurrent = currentStep == step;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.blue.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        border: isCurrent ? Border.all(color: Colors.blue.withOpacity(0.1)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDone ? Colors.blue : (isCurrent ? Colors.amber : Colors.white24),
              fontSize: 16,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 15),
          if (isDone) const Icon(Icons.check, color: Colors.blue, size: 18),
          if (isCurrent)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.amber),
              ),
            ),
          if (!isDone && !isCurrent)
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10, width: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Text(
                'رفع الإمساكية',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _pickFile,
                  child: Container(
                    width: double.infinity,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload, color: Colors.white70, size: 60),
                        const SizedBox(height: 20),
                        const Text(
                          'اسحب وأفلت هنا',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'أو اختر طريقة الرفع أدناه',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          '10MB حتى PNG . JPG . PDF',
                          style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('أو', style: TextStyle(color: Colors.white24, fontSize: 16)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildActionBtn('PDF', Icons.picture_as_pdf, _pickFile)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildActionBtn('المعرض', Icons.photo_library, () => _processImage(ImageSource.gallery))),
                    const SizedBox(width: 15),
                    Expanded(child: _buildActionBtn('الكاميرا', Icons.camera_alt, () => _processImage(ImageSource.camera))),
                  ],
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFFFFD166), size: 18),
                      SizedBox(width: 10),
                      Text(
                        'تأكد أن الإمساكية واضحة وغير مقطوعة',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 30),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
