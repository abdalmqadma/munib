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

  /// Produces a header pass plus overlapping timetable slices. This gives
  /// Tesseract larger text per row and preserves month/year headings.
  Future<List<File>> prepareMonthlyOcrParts(File original) async {
    final bytes = await original.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return [original];

    final oriented = img.bakeOrientation(decoded);
    final files = <File>[];

    final headerHeight = (oriented.height * 0.32).round().clamp(1, oriented.height);
    var header = img.copyCrop(
      oriented,
      x: 0,
      y: 0,
      width: oriented.width,
      height: headerHeight,
    );
    header = _resizeForOcr(header, targetLongEdge: 1800);
    header = img.grayscale(header);
    files.add(await _writeTemp(header, 'munib_ocr_header'));

    final sideMargin = (oriented.width * 0.02).round();
    final bodyTop = (oriented.height * 0.18).round();
    final bodyBottom = (oriented.height * 0.985).round();
    final bodyHeight = (bodyBottom - bodyTop).clamp(1, oriented.height - bodyTop);
    final bodyWidth = (oriented.width - sideMargin * 2).clamp(1, oriented.width);

    final body = img.copyCrop(
      oriented,
      x: sideMargin,
      y: bodyTop,
      width: bodyWidth,
      height: bodyHeight,
    );

    const sliceCount = 4;
    const overlapRatio = 0.10;
    final nominalSliceHeight = body.height / sliceCount;

    for (var i = 0; i < sliceCount; i++) {
      final baseTop = (i * nominalSliceHeight).round();
      final overlap = (nominalSliceHeight * overlapRatio).round();
      final y = (baseTop - (i == 0 ? 0 : overlap)).clamp(0, body.height - 1);
      final nextBase = ((i + 1) * nominalSliceHeight).round();
      final end = (nextBase + (i == sliceCount - 1 ? 0 : overlap))
          .clamp(y + 1, body.height);
      final height = end - y;

      var slice = img.copyCrop(
        body,
        x: 0,
        y: y,
        width: body.width,
        height: height,
      );

      if (slice.width < 2000) {
        slice = img.copyResize(
          slice,
          width: 2000,
          interpolation: img.Interpolation.linear,
        );
      }
      slice = img.grayscale(slice);
      files.add(await _writeTemp(slice, 'munib_ocr_part_${i + 1}'));
    }

    return files;
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
