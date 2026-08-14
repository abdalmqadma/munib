import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/ai_service.dart';
import 'review_screen.dart';
import 'dart:io';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isLoading = false;
  int _loadingStep = 0;
  final OCRService _ocrService = OCRService();
  final AIService _aiService = AIService();

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      _processFile(XFile(result.files.single.path!));
    }
  }

  Future<void> _processImage(ImageSource source) async {
    final picker = ImagePicker();
    // رفع الجودة قليلاً لضمان وضوح الأرقام للـ AI
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1600, 
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (image != null) _processFile(image);
  }

  Future<void> _processFile(XFile file) async {
    setState(() {
      _isLoading = true;
      _loadingStep = 1;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      setState(() => _loadingStep = 2);
      
      List<Map<String, dynamic>> structuredData;
      
      if (file.path.toLowerCase().endsWith('.pdf')) {
        final text = await _ocrService.extractText(file);
        setState(() => _loadingStep = 3);
        structuredData = await _aiService.structurePrayerTimes(text);
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() => _loadingStep = 3);
        structuredData = await _aiService.structurePrayerTimesFromImage(File(file.path));
      }
      
      setState(() => _loadingStep = 4);
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        if (structuredData.isEmpty) {
          _showErrorUI();
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ReviewScreen(initialData: structuredData),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) _showErrorUI();
    } finally {
      if (mounted && !_hasError) setState(() => _isLoading = false);
    }
  }

  bool _hasError = false;
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
              'الصورة غير واضحة. حاول بصورة أوضح مع إضاءة جيدة',
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
            // Robot Avatar
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
            
            // Steps
            _buildLoadingStep(1, "قراءة الصورة", _loadingStep),
            _buildLoadingStep(2, "اكتشاف الجدول", _loadingStep),
            _buildLoadingStep(3, "فهم الجدول وتحليله", _loadingStep),
            _buildLoadingStep(4, "تجهيز أوقات الصلاة", _loadingStep),

            const SizedBox(height: 50),
            
            // Progress Bar
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
                  "${(_loadingStep / 4 * 100).toInt()}%",
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
    bool isDone = currentStep > step;
    bool isCurrent = currentStep == step;

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
          if (isCurrent) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.amber))),
          if (!isDone && !isCurrent) Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white10, width: 2))),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Header
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
              const SizedBox(width: 48), // Spacer
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Drop Zone Box
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
                        style: BorderStyle.solid, // Custom dashed borders are tricky in Flutter without packages
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

                // Action Buttons Grid
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
                // Bottom Hint
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
