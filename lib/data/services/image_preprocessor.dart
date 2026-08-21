import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImagePreprocessor {
  Future<File> prepareForOcr(File original) async {
    final parts = await prepareTableOcrParts(original);
    return parts.length > 1 ? parts[1] : parts.first;
  }

  /// Produces only two OCR images:
  /// 1) a small context crop for month/year/column labels
  /// 2) the timetable itself with grid lines removed
  ///
  /// Removing the grid before OCR is important: Tesseract otherwise mixes
  /// separators, Arabic RTL text and adjacent cells into unrelated lines.
  Future<List<File>> prepareTableOcrParts(File original) async {
    final bytes = await original.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return [original];

    final oriented = img.bakeOrientation(decoded);
    final gray = img.grayscale(oriented.clone());

    final horizontal = _detectHorizontalRules(gray);
    final tableBounds = _chooseTableBounds(gray, horizontal);

    // Context keeps only the useful area immediately above / at the table.
    // This gives the AI month/year/column labels without mosque branding.
    final contextTop = (tableBounds.top - (oriented.height * 0.13).round())
        .clamp(0, oriented.height - 1);
    final contextBottom = (tableBounds.top + (oriented.height * 0.12).round())
        .clamp(contextTop + 1, oriented.height);

    var context = img.copyCrop(
      oriented,
      x: tableBounds.left,
      y: contextTop,
      width: tableBounds.width,
      height: contextBottom - contextTop,
    );
    context = img.grayscale(context);
    context = _binary(context, threshold: 190);
    context = _resizeToWidth(context, 2200);

    var table = img.copyCrop(
      gray,
      x: tableBounds.left,
      y: tableBounds.top,
      width: tableBounds.width,
      height: tableBounds.height,
    );

    table = _binary(table, threshold: 190);

    // Detect rules again on the cropped table so coordinates are local.
    final localHorizontal = _detectHorizontalRules(table);
    final localVertical = _detectVerticalRules(table);

    _eraseHorizontalRules(table, localHorizontal);
    _eraseVerticalRules(table, localVertical);

    // A small white border prevents characters touching the crop edge.
    table = img.copyExpandCanvas(
      table,
      newWidth: table.width + 24,
      newHeight: table.height + 24,
      position: img.ExpandCanvasPosition.center,
      backgroundColor: img.ColorRgb8(255, 255, 255),
    );

    table = _resizeToWidth(table, 3000);

    return [
      await _writeTemp(context, 'munib_ocr_context'),
      await _writeTemp(table, 'munib_ocr_clean_table'),
    ];
  }

  // Kept for compatibility with older callers.
  Future<List<File>> prepareMonthlyOcrParts(File original) =>
      prepareTableOcrParts(original);

  _TableBounds _chooseTableBounds(img.Image image, List<int> rules) {
    final minY = (image.height * 0.22).round();
    final usable = rules.where((y) => y >= minY).toList();

    int top;
    int bottom;

    if (usable.length >= 8) {
      top = (usable.first - 6).clamp(0, image.height - 2);
      bottom = (usable.last + 6).clamp(top + 1, image.height);
    } else {
      // Safe fallback for portrait Imsakia posters.
      top = (image.height * 0.30).round();
      bottom = (image.height * 0.96).round();
    }

    final left = (image.width * 0.018).round();
    final right = (image.width * 0.982).round();

    return _TableBounds(
      left: left,
      top: top,
      width: (right - left).clamp(1, image.width - left),
      height: (bottom - top).clamp(1, image.height - top),
    );
  }

  List<int> _detectHorizontalRules(img.Image image) {
    final candidates = <int>[];
    final xStart = (image.width * 0.03).round();
    final xEnd = (image.width * 0.97).round();
    const step = 3;
    final sampleCount = ((xEnd - xStart) / step).ceil();

    for (var y = 0; y < image.height; y++) {
      var dark = 0;
      for (var x = xStart; x < xEnd; x += step) {
        final p = image.getPixel(x, y);
        if (_luminance(p) < 165) dark++;
      }
      if (sampleCount > 0 && dark / sampleCount >= 0.24) {
        candidates.add(y);
      }
    }

    return _groupPositions(candidates, maxGap: 3);
  }

  List<int> _detectVerticalRules(img.Image image) {
    final candidates = <int>[];
    final yStart = (image.height * 0.02).round();
    final yEnd = (image.height * 0.98).round();
    const step = 3;
    final sampleCount = ((yEnd - yStart) / step).ceil();

    for (var x = 0; x < image.width; x++) {
      var dark = 0;
      for (var y = yStart; y < yEnd; y += step) {
        final p = image.getPixel(x, y);
        if (_luminance(p) < 90) dark++;
      }
      if (sampleCount > 0 && dark / sampleCount >= 0.48) {
        candidates.add(x);
      }
    }

    return _groupPositions(candidates, maxGap: 3);
  }

  List<int> _groupPositions(List<int> values, {required int maxGap}) {
    if (values.isEmpty) return const [];
    final groups = <List<int>>[];
    var current = <int>[values.first];

    for (var i = 1; i < values.length; i++) {
      if (values[i] - values[i - 1] <= maxGap) {
        current.add(values[i]);
      } else {
        groups.add(current);
        current = <int>[values[i]];
      }
    }
    groups.add(current);

    return groups.map((g) => g[g.length ~/ 2]).toList();
  }

  void _eraseHorizontalRules(img.Image image, List<int> rules) {
    for (final y0 in rules) {
      for (var y = (y0 - 2).clamp(0, image.height - 1);
          y <= (y0 + 2).clamp(0, image.height - 1);
          y++) {
        for (var x = 0; x < image.width; x++) {
          image.setPixelRgb(x, y, 255, 255, 255);
        }
      }
    }
  }

  void _eraseVerticalRules(img.Image image, List<int> rules) {
    for (final x0 in rules) {
      for (var x = (x0 - 2).clamp(0, image.width - 1);
          x <= (x0 + 2).clamp(0, image.width - 1);
          x++) {
        for (var y = 0; y < image.height; y++) {
          image.setPixelRgb(x, y, 255, 255, 255);
        }
      }
    }
  }

  img.Image _binary(img.Image source, {required int threshold}) {
    final out = source.clone();
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final p = out.getPixel(x, y);
        final v = _luminance(p) < threshold ? 0 : 255;
        out.setPixelRgb(x, y, v, v, v);
      }
    }
    return out;
  }

  double _luminance(img.Pixel p) =>
      (p.r.toDouble() * 0.299) +
      (p.g.toDouble() * 0.587) +
      (p.b.toDouble() * 0.114);

  img.Image _resizeToWidth(img.Image image, int targetWidth) {
    if (image.width >= targetWidth) return image;
    return img.copyResize(
      image,
      width: targetWidth,
      interpolation: img.Interpolation.cubic,
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

class _TableBounds {
  const _TableBounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int left;
  final int top;
  final int width;
  final int height;
}
