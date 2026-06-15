import 'package:test/test.dart';

import 'package:alibaba_security_cli/src/formatters/json_formatter.dart';
import 'package:alibaba_security_cli/src/formatters/table_formatter.dart';

void main() {
  group('JsonFormatter', () {
    const formatter = JsonFormatter();

    test('format returns pretty JSON for maps', () {
      final result = formatter.format({'key': 'value', 'count': 42});
      expect(result, contains('"key"'));
      expect(result, contains('"value"'));
      expect(result, contains('"count"'));
    });

    test('format returns pretty JSON for lists', () {
      final result = formatter.format([1, 2, 3]);
      expect(result, contains('1'));
      expect(result, contains('2'));
      expect(result, contains('3'));
    });

    test('format handles null', () {
      expect(formatter.format(null), equals('null'));
    });

    test('formatList returns JSON array', () {
      final result = formatter.formatList([
        {'id': '1', 'name': 'first'},
        {'id': '2', 'name': 'second'},
      ]);
      expect(result, contains('"first"'));
      expect(result, contains('"second"'));
    });
  });

  group('TableFormatter', () {
    const formatter = TableFormatter();

    test('printTable does not throw on empty rows', () {
      expect(
        () => formatter.printTable(headers: ['ID', 'Name'], rows: []),
        returnsNormally,
      );
    });

    test('printDetails does not throw', () {
      expect(
        () => formatter.printDetails({
          'Region': 'cn-hangzhou',
          'Mode': 'dry-run',
        }, title: 'Test'),
        returnsNormally,
      );
    });
  });
}
