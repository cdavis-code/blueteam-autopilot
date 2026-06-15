import 'dart:convert';
import 'dart:io' as io;

/// Formats data as pretty-printed JSON for CLI output.
class JsonFormatter {
  const JsonFormatter();

  static const _encoder = JsonEncoder.withIndent('  ');

  /// Format a single object as pretty JSON.
  String format(Object? data) {
    if (data == null) return 'null';

    if (data is Map || data is List) {
      return _encoder.convert(data);
    }

    // For objects with toJson()
    try {
      // ignore: avoid_dynamic_calls
      final json = (data as dynamic).toJson();
      return _encoder.convert(json);
    } catch (_) {
      return data.toString();
    }
  }

  /// Format a list of objects as a JSON array.
  String formatList(List<Object?> items) {
    final jsonList = items.map((item) {
      if (item is Map) return item;
      try {
        // ignore: avoid_dynamic_calls
        return (item as dynamic).toJson() as Map<String, dynamic>;
      } catch (_) {
        return item.toString();
      }
    }).toList();
    return _encoder.convert(jsonList);
  }

  /// Print formatted data to stdout.
  void print(Object? data) {
    io.stdout.writeln(format(data));
  }

  /// Print formatted list to stdout.
  void printList(List<Object?> items) {
    io.stdout.writeln(formatList(items));
  }
}
