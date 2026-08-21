import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImagePreprocessor {
  Future<File> prepareForOcr(File original) async {
    final bytes = await original.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return original;

    var processed = img.bakeOrientation(decoded);

    if (processed.height > processed.width * 1.15) {
      final cropX = (processed.width * 0.025).round();
      final cropY = (processed.height * 0.14).round();
      final cropWidth = processed.width - (cropX * 2);
      final cropHeight = (processed.height * 0.84).round();

      if (cropWidth > 0 &&
          cropHeight > 0 &&
          cropY + cropHeight <= processed.height) {
        processed = img.copyCrop(
          processed,
          x: cropX,
          y: cropY,
          width: cropWidth,
          height: cropHeight,
        );
      }
    }

    processed = _resizeForOcr(processed, targetLongEdge: 2200);
    processed = img.grayscale(processed);

    return _writeTemp(processed, 'munib_ocr_full');
  }

  /// Returns a context/header image followed by row-level timetable crops.
  /// We first try to detect the horizontal grid separators. If the poster uses
  /// faint/non-detectable lines, we fall back to narrow overlapping bands.
  Future<List<File>> prepareMonthlyOcrParts(File original) async {
    final bytes = await original.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return [original];

    final oriented = img.bakeOrientation(decoded);
    final files = <File>[];

    // Keep a generous header/context crop so month + year + column headings
    // remain available to the AI. This is separate from row OCR.
    final contextHeight = (oriented.height * 0.42).round().clamp(1, oriented.height);
    var context = img.copyCrop(
      oriented,
      x: 0,
      y: 0,
      width: oriented.width,
      height: contextHeight,
    );
    context = _resizeForOcr(context, targetLongEdge: 1900);
    context = img.grayscale(context);
    files.add(await _writeTemp(context, 'munib_ocr_context'));

    final sideMargin = (oriented.width * 0.015).round();
    final bodyTop = (oriented.height * 0.20).round();
    final bodyBottom = (oriented.height * 0.99).round();
    final bodyHeight = (bodyBottom - bodyTop).clamp(1, oriented.height - bodyTop);
    final bodyWidth = (oriented.width - sideMargin * 2).clamp(1, oriented.width);

    var body = img.copyCrop(
      oriented,
      x: sideMargin,
      y: bodyTop,
      width: bodyWidth,
      height: bodyHeight,
    );

    // Detect horizontal table separators before grayscale/resizing so geometry
    // still matches the source.
    final separators = _detectHorizontalSeparators(body);
    final rowRanges = _rowRangesFromSeparators(body.height, separators);

    if (rowRanges.length >= 8) {
      // The grid was detected. OCR each visual row independently so Tesseract
      // no longer has to understand a 30-row RTL table at once.
      var rowIndex = 0;
      for (final range in rowRanges) {
        final top = range.$1;
        final height = range.$2;
        if (height < 12) continue;

        final pad = (height * 0.12).round().clamp(2, 14);
        final y = (top - pad).clamp(0, body.height - 1);
        final end = (top + height + pad).clamp(y + 1, body.height);

        var row = img.copyCrop(
          body,
          x: 0,
          y: y,
          width: body.width,
          height: end - y,
        );

        // Row crops are short; width-based enlargement makes Arabic labels and
        // minute-only cells much easier for Tesseract to read.
        if (row.width < 2400) {
          row = img.copyResize(
            row,
            width: 2400,
            interpolation: img.Interpolation.linear,
          );
        }
        row = img.grayscale(row);
        rowIndex++;
        files.add(await _writeTemp(row, 'munib_ocr_row_$rowIndex'));
      }
    } else {
      // Fallback: use many small overlapping horizontal bands rather than four
      // huge chunks. Each band contains roughly 2-3 timetable rows.
      const bandCount = 12;
      const overlapRatio = 0.18;
      final nominal = body.height / bandCount;

      for (var i = 0; i < bandCount; i++) {
        final baseTop = (i * nominal).round();
        final overlap = (nominal * overlapRatio).round();
        final y = (baseTop - (i == 0 ? 0 : overlap)).clamp(0, body.height - 1);
        final nextBase = ((i + 1) * nominal).round();
        final end = (nextBase + (i == bandCount - 1 ? 0 : overlap))
            .clamp(y + 1, body.height);

        var band = img.copyCrop(
          body,
          x: 0,
          y: y,
          width: body.width,
          height: end - y,
        );
        if (band.width < 2200) {
          band = img.copyResize(
            band,
            width: 2200,
            interpolation: img.Interpolation.linear,
          );
        }
        band = img.grayscale(band);
        files.add(await _writeTemp(band, 'munib_ocr_band_${i + 1}'));
      }
    }

    return files;
  }

  List<int> _detectHorizontalSeparators(img.Image image) {
    final candidateYs = <int>[];
    final sampleStep = image.width > 1200 ? 4 : 2;
    final samples = (image.width / sampleStep).ceil();

    for (var y = 0; y < image.height; y++) {
      var dark = 0;
      for (var x = 0; x < image.width; x += sampleStep) {
        final p = image.getPixel(x, y);
        final lum = (p.r.toDouble() + p.g.toDouble() + p.b.toDouble()) / 3.0;
        if (lum < 155) dark++;
      }

      // Text occupies limited horizontal area; a table rule generally spans a
      // large portion of the poster width.
      if (dark / samples >= 0.42) {
        candidateYs.add(y);
      }
    }

    if (candidateYs.isEmpty) return const [];

    final grouped = <List<int>>[];
    var current = <int>[candidateYs.first];
    for (var i = 1; i < candidateYs.length; i++) {
      if (candidateYs[i] - candidateYs[i - 1] <= 2) {
        current.add(candidateYs[i]);
      } else {
        grouped.add(current);
        current = <int>[candidateYs[i]];
      }
    }
    grouped.add(current);

    return grouped
        .map((group) => group[group.length ~/ 2])
        .where((y) => y > 2 && y < image.height - 2)
        .toList();
  }

  List<(int, int)> _rowRangesFromSeparators(
    int imageHeight,
    List<int> separators,
  ) {
    if (separators.length < 4) return const [];

    final ranges = <(int, int)>[];
    for (var i = 0; i < separators.length - 1; i++) {
      final top = separators[i] + 1;
      final bottom = separators[i + 1] - 1;
      final height = bottom - top;

      // Reject separator noise and giant decorative/header regions.
      if (height >= 12 && height <= imageHeight * 0.12) {
        ranges.add((top, height));
      }
    }
    return ranges;
  }

  img.Image _resizeForOcr(
    img.Image image, {
    required int targetLongEdge,
  }) {
    final longEdge = image.width > image.height ? image.width : image.height;
    if (longEdge <= targetLongEdge && longEdge >= 1400) return image;

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
    final output = File(
      '${tempDir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await output.writeAsBytes(img.encodePng(image), flush: true);
    return output;
  }
}
