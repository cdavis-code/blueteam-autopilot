import 'dart:io';

import 'package:ansicolor/ansicolor.dart';

/// Formats data as aligned text tables for CLI output.
class TableFormatter {
  const TableFormatter();

  /// Print a table with headers and rows.
  ///
  /// [headers] are the column header labels.
  /// [rows] are the data rows, each a list of string values.
  /// [title] is an optional title printed above the table.
  void printTable({
    required List<String> headers,
    required List<List<String>> rows,
    String? title,
  }) {
    if (title != null) {
      final titlePen = AnsiPen()..white(bold: true);
      stdout.writeln(titlePen(title));
      stdout.writeln();
    }

    if (rows.isEmpty) {
      stdout.writeln('No results found.');
      return;
    }

    // Calculate column widths
    final widths = List<int>.generate(headers.length, (i) => headers[i].length);
    for (final row in rows) {
      for (var i = 0; i < row.length && i < widths.length; i++) {
        if (row[i].length > widths[i]) {
          widths[i] = row[i].length;
        }
      }
    }

    // Print header
    final headerPen = AnsiPen()..cyan(bold: true);
    final headerLine = _formatRow(headers, widths);
    stdout.writeln(headerPen(headerLine));
    stdout.writeln(_separator(widths));

    // Print rows
    for (final row in rows) {
      stdout.writeln(_formatRow(row, widths));
    }

    stdout.writeln();
    stdout.writeln('${rows.length} result(s)');
  }

  /// Print a key-value detail block.
  void printDetails(Map<String, String> fields, {String? title}) {
    if (title != null) {
      final titlePen = AnsiPen()..white(bold: true);
      stdout.writeln(titlePen(title));
      stdout.writeln();
    }

    final maxKeyLen = fields.keys.fold<int>(
      0,
      (max, k) => k.length > max ? k.length : max,
    );
    final keyPen = AnsiPen()..gray();

    for (final entry in fields.entries) {
      final paddedKey = entry.key.padRight(maxKeyLen);
      stdout.writeln('  ${keyPen(paddedKey)}  ${entry.value}');
    }
    stdout.writeln();
  }

  String _formatRow(List<String> values, List<int> widths) {
    final buffer = StringBuffer('  ');
    for (var i = 0; i < values.length; i++) {
      if (i > 0) buffer.write('  ');
      final width = i < widths.length ? widths[i] : values[i].length;
      buffer.write(values[i].padRight(width));
    }
    return buffer.toString();
  }

  String _separator(List<int> widths) {
    return '  ${widths.map((w) => '─' * w).join('  ')}';
  }
}
