import 'dart:io';

import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import 'image_preprocessor.dart';

class OCRService {
  static const _languages = 'ara+eng';
  static const _trainedDataBaseUrl =
      'https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main';

  static const _ocrArgs = {
    'psm': '6',
    'preserve_interword_spaces': '1',
    'user_defined_dpi': '300',
  };

  final ImagePreprocessor _preprocessor = ImagePreprocessor();

  Future<String> extractText(XFile image) async {
    await _ensureTrainedData();

    final parts = await _preprocessor.prepareMonthlyOcrParts(File(image.path));
    final chunks = <String>[];

    try {
      for (var i = 0; i < parts.length; i++) {
        final text = await FlutterTesseractOcr.extractText(
          parts[i].path,
          language: _languages,
          args: _ocrArgs,
        );

        if (text.trim().isEmpty) continue;

        if (i == 0) {
          chunks.add('=== HEADER / MONTH / YEAR / COLUMN CONTEXT ===\n$text');
        } else {
          chunks.add('=== TABLE ROW CANDIDATE $i ===\n$text');
        }
      }
    } finally {
      for (final part in parts) {
        if (part.path != image.path && await part.exists()) {
          await part.delete();
        }
      }
    }

    return chunks.join('\n\n');
  }

  Future<String> extractTextFromPdf(File pdfFile) async {
    await _ensureTrainedData();

    final document = await PdfDocument.openFile(pdfFile.path);
    final chunks = <String>[];

    try {
      for (var pageNumber = 1; pageNumber <= document.pagesCount; pageNumber++) {
        final page = await document.getPage(pageNumber);
        try {
          final rendered = await page.render(
            width: page.width * 2.2,
            height: page.height * 2.2,
            format: PdfPageImageFormat.png,
            backgroundColor: '#ffffff',
          );

          if (rendered == null) continue;

          final tempDir = await getTemporaryDirectory();
          final imageFile = File(
            '${tempDir.path}/munib_pdf_${DateTime.now().microsecondsSinceEpoch}_$pageNumber.png',
          );
          await imageFile.writeAsBytes(rendered.bytes);

          try {
            final pageText = await extractText(XFile(imageFile.path));
            if (pageText.trim().isNotEmpty) {
              chunks.add('=== PDF PAGE $pageNumber ===\n$pageText');
            }
          } finally {
            if (await imageFile.exists()) await imageFile.delete();
          }
        } finally {
          await page.close();
        }
      }
    } finally {
      await document.close();
    }

    return chunks.join('\n\n');
  }

  Future<void> _ensureTrainedData() async {
    final tessDataPath = await FlutterTesseractOcr.getTessdataPath();
    final directory = Directory(tessDataPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    for (final language in const ['ara', 'eng']) {
      final target = File('$tessDataPath/$language.traineddata');
      if (await target.exists() && await target.length() > 0) continue;

      final response = await http.get(
        Uri.parse('$_trainedDataBaseUrl/$language.traineddata'),
      );

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception('Unable to download $language OCR model.');
      }

      await target.writeAsBytes(response.bodyBytes, flush: true);
    }
  }
}
