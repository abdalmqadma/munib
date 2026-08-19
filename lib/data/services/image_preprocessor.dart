import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImagePreprocessor {
  Future<File> prepareForOcr(File original) async {
    final bytes = await original.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return original;

    var processed = decoded;

    // Keep enough resolution for small table cells and prayer-time digits.
    const maxDimension = 2400;
    if (processed.width > maxDimension || processed.height > maxDimension) {
      processed = img.copyResize(
        processed,
        width: processed.width >= processed.height ? maxDimension : null,
        height: processed.height > processed.width ? maxDimension : null,
        maintainAspect: true,
        interpolation: img.Interpolation.linear,
      );
    }

    // Grayscale improves contrast between table text and a light background
    // without applying destructive thresholding or aggressive compression.
    processed = img.grayscale(processed);

    final tempDir = await getTemporaryDirectory();
    final output = File(
      '${tempDir.path}/munib_ocr_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await output.writeAsBytes(img.encodePng(processed), flush: true);
    return output;
  }
}
