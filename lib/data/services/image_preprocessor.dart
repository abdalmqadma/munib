import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImagePreprocessor {
  Future<File> prepareForOcr(File original) async {
    final bytes = await original.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return original;

    var processed = img.bakeOrientation(decoded);

    // Timetable cells contain very small Arabic text and digits. Upscale smaller
    // images instead of only shrinking large ones so Tesseract gets more pixels
    // per character.
    const targetLongEdge = 3200;
    final longEdge = processed.width > processed.height
        ? processed.width
        : processed.height;
    if (longEdge != targetLongEdge) {
      final scale = targetLongEdge / longEdge;
      processed = img.copyResize(
        processed,
        width: (processed.width * scale).round(),
        height: (processed.height * scale).round(),
        interpolation: img.Interpolation.cubic,
      );
    }

    processed = img.grayscale(processed);

    // Stretch the luminance range. This makes faint table digits more distinct
    // while retaining grid lines that help Tesseract understand rows.
    final stats = _luminanceRange(processed);
    if (stats.$2 > stats.$1) {
      final minValue = stats.$1;
      final range = stats.$2 - stats.$1;
      for (final pixel in processed) {
        final value = pixel.r.toDouble();
        final normalized = ((value - minValue) * 255.0 / range)
            .clamp(0.0, 255.0)
            .round();
        pixel
          ..r = normalized
          ..g = normalized
          ..b = normalized;
      }
    }

    final tempDir = await getTemporaryDirectory();
    final output = File(
      '${tempDir.path}/munib_ocr_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await output.writeAsBytes(img.encodePng(processed), flush: true);
    return output;
  }

  (double, double) _luminanceRange(img.Image image) {
    var minValue = 255.0;
    var maxValue = 0.0;
    for (final pixel in image) {
      final value = pixel.r.toDouble();
      if (value < minValue) minValue = value;
      if (value > maxValue) maxValue = value;
    }
    return (minValue, maxValue);
  }
}
