import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImagePreprocessor {
  Future<File> prepareForOcr(File original) async {
    final bytes = await original.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return original;
    var processed = img.bakeOrientation(decoded);
    processed = _resizeForOcr(processed, targetLongEdge: 2200);
    processed = img.grayscale(processed);
    return _writeTemp(processed, 'munib_ocr_full');
  }

  /// Creates one context image plus narrow horizontal row images.
  /// We deliberately do not ask Tesseract to understand the whole table.
  Future<List<File>> prepareMonthlyOcrParts(File original) async {
    final bytes = await original.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return [original];

    final source = img.bakeOrientation(decoded);
    final files = <File>[];

    // Header/context: enough to capture month, year and column labels.
    final contextHeight = (source.height * 0.34).round().clamp(1, source.height);
    var context = img.copyCrop(
      source,
      x: 0,
      y: 0,
      width: source.width,
      height: contextHeight,
    );
    context = _resizeForOcr(context, targetLongEdge: 1800);
    context = img.grayscale(context);
    files.add(await _writeTemp(context, 'munib_ocr_context'));

    // For the current official-style imsakia layout the timetable occupies
    // approximately this vertical region. Split it into many thin rows so
    // OCR preserves columns instead of merging unrelated days.
    final left = (source.width * 0.018).round();
    final right = (source.width * 0.982).round();
    final top = (source.height * 0.245).round();
    final bottom = (source.height * 0.915).round();
    final width = (right - left).clamp(1, source.width - left);
    final height = (bottom - top).clamp(1, source.height - top);

    final table = img.copyCrop(
      source,
      x: left,
      y: top,
      width: width,
      height: height,
    );

    // 31 slots lets us support a full Gregorian month. Small vertical padding
    // keeps digits close to row borders from being clipped.
    const rowCount = 31;
    final rowHeight = table.height / rowCount;
    for (var i = 0; i < rowCount; i++) {
      final nominalTop = (i * rowHeight).round();
      final nominalBottom = ((i + 1) * rowHeight).round();
      final pad = (rowHeight * 0.18).round().clamp(1, 8);
      final y = (nominalTop - pad).clamp(0, table.height - 1);
      final end = (nominalBottom + pad).clamp(y + 1, table.height);

      var row = img.copyCrop(
        table,
        x: 0,
        y: y,
        width: table.width,
        height: end - y,
      );

      // Upscale only the row, not the entire source image. This is much lighter
      // on memory while giving Tesseract larger prayer-time digits.
      final targetWidth = row.width < 1800 ? 1800 : row.width;
      if (row.width != targetWidth) {
        row = img.copyResize(
          row,
          width: targetWidth,
          interpolation: img.Interpolation.linear,
        );
      }
      row = img.grayscale(row);
      files.add(await _writeTemp(row, 'munib_ocr_row_${i + 1}'));
    }

    return files;
  }

  img.Image _resizeForOcr(img.Image image, {required int targetLongEdge}) {
    final longEdge = image.width > image.height ? image.width : image.height;
    if (longEdge <= targetLongEdge && longEdge >= 1200) return image;
    final scale = targetLongEdge / longEdge;
    return img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.linear,
    );
  }

  Future<File> _writeTemp(img.Image image, String prefix) async {
    final tempDir = await getTemporaryDirectory();
    final output = File('${tempDir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await output.writeAsBytes(img.encodeJpg(image, quality: 90), flush: true);
    return output;
  }
}
