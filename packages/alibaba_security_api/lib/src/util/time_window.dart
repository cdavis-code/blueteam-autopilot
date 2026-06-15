/// Time window utilities for security event queries.
///
/// Provides pre-baked relative time shortcuts and guardrails to prevent
/// agents from requesting excessive lookback periods. All computations
/// use Dart-native DateTime math — never rely on LLM date arithmetic.
library;

/// Pre-baked relative time shortcuts for common SecOps queries.
///
/// When an agent selects a shortcut, Dart computes the exact boundaries
/// at call time, eliminating LLM date-math errors.
enum TimeRange {
  /// Last 15 minutes — real-time monitoring window.
  last15Min('Last 15 minutes', Duration(minutes: 15)),

  /// Last 1 hour — recent activity window.
  lastHour('Last hour', Duration(hours: 1)),

  /// Last 4 hours — short-term investigation window.
  last4Hours('Last 4 hours', Duration(hours: 4)),

  /// Last 24 hours — daily overview window.
  last24Hours('Last 24 hours', Duration(hours: 24)),

  /// Last 7 days — weekly trend window.
  last7Days('Last 7 days', Duration(days: 7)),

  /// Last 30 days — monthly overview window.
  last30Days('Last 30 days', Duration(days: 30)),

  /// Custom range — requires explicit start/end ISO 8601 strings.
  custom('Custom range', Duration.zero);

  /// Human-readable label for this range.
  final String label;

  /// The lookback duration from "now" for this range.
  final Duration lookback;

  const TimeRange(this.label, this.lookback);

  /// Parse a string to [TimeRange], case-insensitive.
  ///
  /// Accepts enum names (e.g., "last15Min", "LAST_HOUR") or labels.
  /// Returns [TimeRange.custom] if no match is found.
  static TimeRange fromString(String? value) {
    if (value == null || value.isEmpty) return TimeRange.lastHour;
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');
    return switch (normalized) {
      'last15min' || 'last15minutes' || '15m' || '15min' => TimeRange.last15Min,
      'lasthour' || '1h' || '60m' || '60min' => TimeRange.lastHour,
      'last4hours' || '4h' || '240m' => TimeRange.last4Hours,
      'last24hours' || '24h' || '1d' || '1440m' => TimeRange.last24Hours,
      'last7days' || '7d' || '1w' || '1week' => TimeRange.last7Days,
      'last30days' || '30d' || '1month' => TimeRange.last30Days,
      'custom' => TimeRange.custom,
      _ => TimeRange.lastHour,
    };
  }
}

/// A computed time window with start and end boundaries.
///
/// All security event queries should use [TimeWindow] to ensure:
/// 1. Precise, Dart-computed boundaries (no LLM date math)
/// 2. Guardrails against excessive lookback (max 30 days by default)
/// 3. Consistent format output (ISO 8601 or Unix epoch)
class TimeWindow {
  /// The start of the window (inclusive).
  final DateTime start;

  /// The end of the window (inclusive).
  final DateTime end;

  /// The [TimeRange] shortcut used, or [TimeRange.custom] if explicit.
  final TimeRange range;

  TimeWindow._({
    required this.start,
    required this.end,
    this.range = TimeRange.custom,
  });

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  /// Create a time window from a pre-baked [TimeRange] shortcut.
  ///
  /// Computes exact start/end from [TimeRange.lookback] relative to now.
  /// If [now] is not provided, uses [DateTime.now] in UTC.
  factory TimeWindow.fromRange(TimeRange range, {DateTime? now}) {
    final current = (now ?? DateTime.now()).toUtc();
    if (range == TimeRange.custom) {
      throw ArgumentError(
        'Cannot create TimeWindow from TimeRange.custom. '
        'Use TimeWindow.fromIso8601() for custom ranges.',
      );
    }
    return TimeWindow._(
      start: current.subtract(range.lookback),
      end: current,
      range: range,
    );
  }

  /// Create a time window from explicit ISO 8601 strings.
  ///
  /// Parses [startIso] and [endIso] as UTC DateTimes. Applies guardrails
  /// to enforce [maxLookbackDays] (default: 30 days).
  factory TimeWindow.fromIso8601(
    String startIso,
    String endIso, {
    int maxLookbackDays = 30,
  }) {
    final parsedStart = DateTime.parse(startIso).toUtc();
    final parsedEnd = DateTime.parse(endIso).toUtc();

    final window = TimeWindow._(
      start: parsedStart,
      end: parsedEnd,
      range: TimeRange.custom,
    );

    return window.enforceGuardrails(maxLookbackDays: maxLookbackDays);
  }

  /// Create a time window from Unix epoch seconds.
  factory TimeWindow.fromEpoch(
    int startEpoch,
    int endEpoch, {
    int maxLookbackDays = 30,
  }) {
    return TimeWindow.fromIso8601(
      DateTime.fromMillisecondsSinceEpoch(
        startEpoch * 1000,
        isUtc: true,
      ).toIso8601String(),
      DateTime.fromMillisecondsSinceEpoch(
        endEpoch * 1000,
        isUtc: true,
      ).toIso8601String(),
      maxLookbackDays: maxLookbackDays,
    );
  }

  /// Smart factory: accepts either a [TimeRange] shortcut or custom ISO
  /// strings. This is the primary entry point for MCP tool parameters.
  ///
  /// Priority:
  /// 1. If [range] is not null and not `custom`, use the shortcut.
  /// 2. If [startIso] and [endIso] are provided, use custom range.
  /// 3. Default to [TimeRange.lastHour].
  factory TimeWindow.resolve({
    TimeRange? range,
    String? startIso,
    String? endIso,
    int maxLookbackDays = 30,
  }) {
    // If a non-custom shortcut is specified, use it directly
    if (range != null && range != TimeRange.custom) {
      return TimeWindow.fromRange(range);
    }

    // If explicit ISO strings are provided, use custom range
    if (startIso != null && endIso != null) {
      return TimeWindow.fromIso8601(
        startIso,
        endIso,
        maxLookbackDays: maxLookbackDays,
      );
    }

    // Default: last hour
    return TimeWindow.fromRange(TimeRange.lastHour);
  }

  // ---------------------------------------------------------------------------
  // Output formats
  // ---------------------------------------------------------------------------

  /// Start time as ISO 8601 string (UTC).
  String get startIso8601 => start.toIso8601String();

  /// End time as ISO 8601 string (UTC).
  String get endIso8601 => end.toIso8601String();

  /// Start time as Unix epoch seconds.
  int get startEpochSeconds => start.millisecondsSinceEpoch ~/ 1000;

  /// End time as Unix epoch seconds.
  int get endEpochSeconds => end.millisecondsSinceEpoch ~/ 1000;

  /// Start time as Unix epoch milliseconds.
  int get startEpochMillis => start.millisecondsSinceEpoch;

  /// End time as Unix epoch milliseconds.
  int get endEpochMillis => end.millisecondsSinceEpoch;

  /// Duration of this window.
  Duration get duration => end.difference(start);

  /// Duration in minutes (rounded down).
  int get durationMinutes => duration.inMinutes;

  // ---------------------------------------------------------------------------
  // Guardrails
  // ---------------------------------------------------------------------------

  /// Enforce maximum lookback period. If the window exceeds [maxLookbackDays],
  /// the start is clamped to `now - maxLookbackDays`.
  ///
  /// This prevents agents from accidentally requesting months of verbose
  /// alert data that could cause API timeouts or excessive costs.
  TimeWindow enforceGuardrails({int maxLookbackDays = 30, DateTime? now}) {
    final current = (now ?? DateTime.now()).toUtc();
    final maxPast = current.subtract(Duration(days: maxLookbackDays));

    final clampedStart = start.isBefore(maxPast) ? maxPast : start;
    final clampedEnd = end.isAfter(current) ? current : end;

    if (clampedStart == start && clampedEnd == end) return this;

    return TimeWindow._(
      start: clampedStart,
      end: clampedEnd,
      range: range == TimeRange.custom ? TimeRange.custom : range,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  /// JSON-friendly representation with all output formats.
  Map<String, dynamic> toJson() => {
    'start': startIso8601,
    'end': endIso8601,
    'startEpochSeconds': startEpochSeconds,
    'endEpochSeconds': endEpochSeconds,
    'range': range.name,
    'durationMinutes': durationMinutes,
  };

  /// Compact summary string for logging/display.
  String toSummary() =>
      '${range.label}: $startIso8601 → $endIso8601 (${durationMinutes}min)';

  @override
  String toString() =>
      'TimeWindow($startIso8601 → $endIso8601, ${range.label})';
}
