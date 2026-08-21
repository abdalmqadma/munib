import 'package:flutter_test/flutter_test.dart';
import 'package:munib/data/services/imsakia_parser.dart';

void main() {
  final parser = ImsakiaParser();

  test('normalizes Arabic and Persian digits', () {
    final result = parser.normalizeOcrText('الفجر ٠٤:٣٠\nالشروق ۰۵:۵۵');

    expect(result, contains('04:30'));
    expect(result, contains('05:55'));
  });

  test('extracts time-like OCR tokens conservatively', () {
    final tokens = parser.extractTimeTokens('الفجر 04:30 الشروق 05.55 رقم 9999');

    expect(tokens, containsAll(['04:30', '05.55']));
    expect(tokens, isNot(contains('9999')));
  });
}
