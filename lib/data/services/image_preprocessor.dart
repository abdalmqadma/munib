import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImagePreprocessor {
  Future<File> prepareForOcr(File original) async {
    final bytes = await original.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return original;

    var processed = img.bakeOrientation(decoded);

    // Most photographed Imsakia sheets are portrait posters where the upper
    // area contains branding, mosque photos and headings while the actual
    // timetable begins lower down. Cropping that decorative area improves OCR
    // row consistency and avoids sending irrelevant text to the AI.
    if (processed.height > processed.width * 1.15) {
      final cropX = (processed.width * 0.025).round();
      final cropY = (processed.height * 0.18).round();
      final cropWidth = processed.width - (cropX * 2);
      final cropHeight = (processed.height * 0.805).round();

      if (cropWidth > 0 && cropHeight > 0 && cropY + cropHeight <= processed.height) {
        processed = img.copyCrop(
          processed,
          x: cropX,
          y: cropY,
          width: cropWidth,
          height: cropHeight,
        );
      }
    }

    // Enough detail for small timetable digits without freezing mid-range phones.
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

    processed = img.grayscale(processed);

    final tempDir = await getTemporaryDirectory();
    final output = File(
      '${tempDir.path}/munib_ocr_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await output.writeAsBytes(img.encodePng(processed), flush: true);
    return output;
  }
}
