import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImagePreprocessor {
  Future<File> prepareForOcr(File original) async {
    final bytes = await original.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return original;

    var processed = img.bakeOrientation(decoded);

    // Keep enough detail for timetable cells without creating a huge image
    // that freezes lower/mid-range phones during preprocessing and OCR.
    const targetLongEdge = 2200;
    final longEdge = processed.width > processed.height
        ? processed.width
        : processed.height;

    if (longEdge > targetLongEdge || longEdge < 1600) {
      final scale = targetLongEdge / longEdge;
      processed = img.copyResize(
        processed,
        width: (processed.width * scale).round(),
        height: (processed.height * scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }

    // Lightweight preprocessing only. The previous per-pixel contrast pass
    // caused noticeable UI stalls and made OCR much slower on device.
    processed = img.grayscale(processed);

    final tempDir = await getTemporaryDirectory();
    final output = File(
      '${tempDir.path}/munib_ocr_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await output.writeAsBytes(img.encodePng(processed), flush: true);
    return output;
  }
}
