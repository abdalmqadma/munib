class ImsakiaParser {
  static const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  static const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';
  static const _latinDigits = '0123456789';

  /// Normalizes common Arabic OCR variants before the AI structuring step.
  /// It deliberately does not invent rows or prayer times.
  String normalizeOcrText(String rawText) {
    var text = rawText;

    for (var i = 0; i < _latinDigits.length; i++) {
      text = text.replaceAll(_arabicDigits[i], _latinDigits[i]);
      text = text.replaceAll(_persianDigits[i], _latinDigits[i]);
    }

    text = text
        .replaceAll('٫', '.')
        .replaceAll('٬', ',')
        .replaceAll('؛', ';')
        .replaceAll('：', ':')
        .replaceAll('٠', '0')
        .replaceAll(RegExp(r'[\u200e\u200f]'), '');

    final normalizedLines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return normalizedLines.join('\n');
  }

  /// Returns time-like tokens from OCR without deciding which prayer they
  /// belong to. This is useful as a conservative hint for the AI parser.
  List<String> extractTimeTokens(String rawText) {
    final normalized = normalizeOcrText(rawText);
    return RegExp(r'(?<!\d)(?:[01]?\d|2[0-3])\s*[:.]\s*[0-5]\d(?!\d)')
        .allMatches(normalized)
        .map((match) => match.group(0)!.replaceAll(RegExp(r'\s+'), ''))
        .toList();
  }
}
