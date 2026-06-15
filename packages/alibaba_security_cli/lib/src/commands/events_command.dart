import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:alibaba_security_api/alibaba_security_api.dart';

import '../config/cli_config.dart';
import '../formatters/json_formatter.dart';
import '../formatters/table_formatter.dart';

/// `alsec events` — list and get security events (C2, C3).
class EventsCommand extends Command<void> {
  @override
  final String name = 'events';

  @override
  final String description =
      'List and get security events (C2) or get event details (C3).';

  final CliConfig config;

  EventsCommand(this.config) {
    addSubcommand(EventsListCommand(config));
    addSubcommand(EventsGetCommand(config));
    addSubcommand(WafEventsCommand(config));
  }
}

/// `alsec events list` — list security events within a time window.
///
/// Queries Security Center (SAS) and WAF. WAF instance is auto-discovered
/// via DescribeInstance if not explicitly configured.
class EventsListCommand extends Command<void> {
  @override
  final String name = 'list';

  @override
  final String description =
      'List security events from Security Center and/or WAF.';

  final CliConfig config;

  EventsListCommand(this.config) {
    argParser
      ..addOption(
        'time-range',
        abbr: 't',
        help:
            'Pre-baked time window shortcut. Takes precedence over --minutes. '
            'Options: last15Min, lastHour, last4Hours, last24Hours, last7Days, last30Days.',
      )
      ..addOption(
        'minutes',
        abbr: 'm',
        help:
            'Time window in minutes (default: 60). Ignored if --time-range is set.',
        defaultsTo: '60',
      )
      ..addOption(
        'severity',
        abbr: 's',
        help: 'Minimum severity filter (low, medium, high, critical).',
      )
      ..addOption(
        'status',
        help: 'Filter by event status (new, in_progress, resolved).',
      )
      ..addOption(
        'source',
        help: 'Event source: sas, waf, or all (default: all).',
        defaultsTo: 'all',
      );
  }

  @override
  Future<void> run() async {
    final client = config.createClient();
    final jsonFmt = config.jsonOutput ? const JsonFormatter() : null;
    const tableFmt = TableFormatter();

    // Resolve time window: --time-range shortcut takes precedence over --minutes
    final timeRangeStr = argResults!['time-range'] as String?;
    final minutes = int.tryParse(argResults!['minutes'] as String) ?? 60;

    final TimeWindow window;
    if (timeRangeStr != null && timeRangeStr.isNotEmpty) {
      window = TimeWindow.fromRange(TimeRange.fromString(timeRangeStr));
    } else {
      // Legacy: convert minutes to TimeWindow
      final now = DateTime.now().toUtc();
      final start = now.subtract(Duration(minutes: minutes));
      window = TimeWindow.fromIso8601(
        start.toIso8601String(),
        now.toIso8601String(),
      );
    }
    final severityStr = argResults!['severity'] as String?;
    final statusStr = argResults!['status'] as String?;
    final source = argResults!['source'] as String? ?? 'all';

    try {
      // Collect events from requested sources
      final allEvents = <Map<String, dynamic>>[];

      // SAS events (Security Center)
      if (source == 'all' || source == 'sas') {
        final sasService = SecurityCenterService(client);
        final sasEvents = await sasService.listSecurityEvents(
          window: window,
          minSeverity: severityStr != null
              ? Severity.fromString(severityStr)
              : null,
          status: statusStr != null ? EventStatus.fromString(statusStr) : null,
        );
        for (final e in sasEvents) {
          allEvents.add({
            'id': e.eventId,
            'title': e.title,
            'severity': e.severity,
            'sources': e.sourceProducts.join(', '),
            'firstSeen': e.firstSeen ?? '-',
            'source': 'SAS',
          });
        }
      }

      // WAF events (auto-discovered)
      if (source == 'all' || source == 'waf') {
        try {
          final wafService = WafService(
            client,
            instanceId: config.wafInstanceId,
          );
          final result = await wafService.listSecurityEventLogs(
            startDate: window.startEpochSeconds,
            endDate: window.endEpochSeconds,
          );
          for (final e in result.events) {
            allEvents.add({
              'id': e.requestTraceId,
              'title': '${e.attackType} (${e.action})',
              'severity': _wafActionToSeverity(e.action),
              'sources':
                  '${e.sourceIp}${e.countryCode != null ? " (${e.countryCode})" : ""}',
              'firstSeen': e.timestamp,
              'source': 'WAF',
              'ruleId': e.ruleId,
              'ruleType': e.ruleType,
              'host': e.host,
              'requestPath': e.requestPath,
            });
          }
        } catch (_) {
          // WAF not available in this region/account — skip silently
        }
      }

      if (jsonFmt != null) {
        stdout.writeln(const JsonEncoder.withIndent('  ').convert(allEvents));
      } else {
        tableFmt.printTable(
          title:
              'Security Events (${window.range.label}) — ${allEvents.length} total',
          headers: ['Source', 'ID', 'Title', 'Severity', 'First Seen'],
          rows: allEvents
              .map(
                (e) => [
                  e['source'] as String,
                  _truncate(e['id'] as String, 20),
                  _truncate(e['title'] as String, 40),
                  e['severity'] as String,
                  e['firstSeen'] as String,
                ],
              )
              .toList(),
        );

        // Print WAF-specific summary if WAF events present
        final wafEvents = allEvents.where((e) => e['source'] == 'WAF').toList();
        if (wafEvents.isNotEmpty && !config.jsonOutput) {
          stdout.writeln();
          stdout.writeln('  WAF Summary:');
          stdout.writeln('    ${wafEvents.length} attack(s) detected');
          final ips = wafEvents.map((e) => e['sources'] as String).toSet();
          stdout.writeln('    Source IPs: ${ips.join(", ")}');
          final hosts = wafEvents
              .map((e) => e['host'] as String?)
              .where((h) => h != null)
              .toSet();
          if (hosts.isNotEmpty) {
            stdout.writeln('    Target hosts: ${hosts.join(", ")}');
          }
          stdout.writeln();
        }
      }
    } on AlibabaApiError catch (e) {
      _handleError(e, jsonFmt);
    }
  }
}

/// `alsec events get <eventId>` — get full event details.
class EventsGetCommand extends Command<void> {
  @override
  final String name = 'get';

  @override
  final String description = 'Get detailed information about a security event.';

  final CliConfig config;

  EventsGetCommand(this.config);

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      stderr.writeln(
        'Error: eventId is required. Usage: alsec events get <eventId>',
      );
      exitCode = 64;
      return;
    }

    final eventId = rest.first;
    final client = config.createClient();
    final service = SecurityCenterService(client);
    final jsonFmt = config.jsonOutput ? const JsonFormatter() : null;
    const tableFmt = TableFormatter();

    try {
      final detail = await service.getSecurityEventDetail(eventId);

      if (jsonFmt != null) {
        jsonFmt.print(detail);
      } else {
        tableFmt.printDetails({
          'Event ID': detail.eventId,
          'Title': detail.title,
          'Severity': detail.severity,
          'Source': detail.source ?? '-',
          'Attackers': detail.attackers.join(', ').isEmpty
              ? '-'
              : detail.attackers.join(', '),
          'Countries': detail.attackerCountries.join(', ').isEmpty
              ? '-'
              : detail.attackerCountries.join(', '),
          'Related Alerts': '${detail.relatedAlerts.length}',
          'Related Vulns': detail.relatedVulnerabilities.join(', ').isEmpty
              ? '-'
              : detail.relatedVulnerabilities.join(', '),
        }, title: 'Event Detail');

        if (detail.attackChain.isNotEmpty) {
          stdout.writeln('  Attack Chain:');
          for (final stage in detail.attackChain) {
            stdout.writeln('    ${stage.stage}: ${stage.description}');
          }
          stdout.writeln();
        }
      }
    } on AlibabaApiError catch (e) {
      _handleError(e, jsonFmt);
    }
  }
}

/// `alsec events waf` — WAF-specific security event commands.
///
/// Provides detailed WAF attack logs, top rule hits, and top attacker IPs.
class WafEventsCommand extends Command<void> {
  @override
  final String name = 'waf';

  @override
  final String description =
      'List WAF attack events, top rules, and top attacker IPs.';

  final CliConfig config;

  WafEventsCommand(this.config) {
    addSubcommand(WafLogsCommand(config));
    addSubcommand(WafTopRulesCommand(config));
    addSubcommand(WafTopIpsCommand(config));
  }
}

/// `alsec events waf logs` — detailed WAF attack log entries.
class WafLogsCommand extends Command<void> {
  @override
  final String name = 'logs';

  @override
  final String description = 'List detailed WAF attack log entries.';

  final CliConfig config;

  WafLogsCommand(this.config) {
    argParser
      ..addOption(
        'minutes',
        abbr: 'm',
        help: 'Time window in minutes (default: 1440 = 24h).',
        defaultsTo: '1440',
      )
      ..addOption(
        'page-size',
        help: 'Number of entries per page (max 100).',
        defaultsTo: '20',
      )
      ..addOption('page', help: 'Page number.', defaultsTo: '1');
  }

  @override
  Future<void> run() async {
    final client = config.createClient();
    final wafService = WafService(client, instanceId: config.wafInstanceId);
    final jsonFmt = config.jsonOutput ? const JsonFormatter() : null;
    const tableFmt = TableFormatter();

    final minutes = int.tryParse(argResults!['minutes'] as String) ?? 1440;
    final pageSize = int.tryParse(argResults!['page-size'] as String) ?? 20;
    final page = int.tryParse(argResults!['page'] as String) ?? 1;

    try {
      final result = await wafService.listRecentSecurityEvents(
        minutes: minutes,
        page: page,
        pageSize: pageSize,
      );

      if (jsonFmt != null) {
        stdout.writeln(
          const JsonEncoder.withIndent('  ').convert({
            'totalCount': result.totalCount,
            'page': page,
            'pageSize': pageSize,
            'events': result.events.map((e) => e.toJson()).toList(),
          }),
        );
      } else {
        tableFmt.printTable(
          title: 'WAF Attack Logs (${result.totalCount} total)',
          headers: [
            'Time',
            'Attack Type',
            'Source IP',
            'Action',
            'Host',
            'Path',
          ],
          rows: result.events
              .map(
                (e) => [
                  e.timestamp,
                  e.attackType,
                  e.sourceIp,
                  e.action,
                  e.host ?? '-',
                  _truncate(e.requestPath, 30),
                ],
              )
              .toList(),
        );
      }
    } on AlibabaApiError catch (e) {
      _handleError(e, jsonFmt);
    }
  }
}

/// `alsec events waf top-rules` — top triggered WAF rules.
class WafTopRulesCommand extends Command<void> {
  @override
  final String name = 'top-rules';

  @override
  final String description = 'Show top 10 most frequently triggered WAF rules.';

  final CliConfig config;

  WafTopRulesCommand(this.config) {
    argParser.addOption(
      'days',
      abbr: 'd',
      help: 'Lookback period in days (default: 7).',
      defaultsTo: '7',
    );
  }

  @override
  Future<void> run() async {
    final client = config.createClient();
    final wafService = WafService(client, instanceId: config.wafInstanceId);
    final jsonFmt = config.jsonOutput ? const JsonFormatter() : null;
    const tableFmt = TableFormatter();

    final days = int.tryParse(argResults!['days'] as String) ?? 7;
    final now = DateTime.now().toUtc();
    final endTs = now.millisecondsSinceEpoch ~/ 1000;
    final startTs =
        now.subtract(Duration(days: days)).millisecondsSinceEpoch ~/ 1000;

    try {
      final ruleHits = await wafService.getTopRuleHits(
        startTimestamp: startTs,
        endTimestamp: endTs,
      );

      if (jsonFmt != null) {
        jsonFmt.printList(ruleHits.map((r) => r.toJson()).toList());
      } else {
        tableFmt.printTable(
          title: 'Top WAF Rules (last $days days)',
          headers: ['Rule ID', 'Hit Count'],
          rows: ruleHits.map((r) => [r.ruleId, '${r.count}']).toList(),
        );
      }
    } on AlibabaApiError catch (e) {
      _handleError(e, jsonFmt);
    }
  }
}

/// `alsec events waf top-ips` — top attacker IPs.
class WafTopIpsCommand extends Command<void> {
  @override
  final String name = 'top-ips';

  @override
  final String description = 'Show top 10 source IPs by attack count.';

  final CliConfig config;

  WafTopIpsCommand(this.config) {
    argParser.addOption(
      'days',
      abbr: 'd',
      help: 'Lookback period in days (default: 7).',
      defaultsTo: '7',
    );
  }

  @override
  Future<void> run() async {
    final client = config.createClient();
    final wafService = WafService(client, instanceId: config.wafInstanceId);
    final jsonFmt = config.jsonOutput ? const JsonFormatter() : null;
    const tableFmt = TableFormatter();

    final days = int.tryParse(argResults!['days'] as String) ?? 7;
    final now = DateTime.now().toUtc();
    final endTs = now.millisecondsSinceEpoch ~/ 1000;
    final startTs =
        now.subtract(Duration(days: days)).millisecondsSinceEpoch ~/ 1000;

    try {
      final topIps = await wafService.getTopAttackerIps(
        startTimestamp: startTs,
        endTimestamp: endTs,
      );

      if (jsonFmt != null) {
        jsonFmt.printList(topIps);
      } else {
        tableFmt.printTable(
          title: 'Top Attacker IPs (last $days days)',
          headers: ['IP Address', 'Hit Count'],
          rows: topIps
              .map(
                (r) => [
                  r['ClientIp']?.toString() ?? '-',
                  r['Count']?.toString() ?? '-',
                ],
              )
              .toList(),
        );
      }
    } on AlibabaApiError catch (e) {
      _handleError(e, jsonFmt);
    }
  }
}

String _truncate(String s, int maxLen) =>
    s.length > maxLen ? '${s.substring(0, maxLen - 3)}...' : s;

String _wafActionToSeverity(String action) => switch (action) {
  'block' => 'HIGH',
  'monitor' => 'MEDIUM',
  'captcha' => 'LOW',
  'js' => 'LOW',
  _ => 'MEDIUM',
};

void _handleError(AlibabaApiError e, JsonFormatter? jsonFmt) {
  if (jsonFmt != null) {
    jsonFmt.print(e.toJson());
  } else {
    stderr.writeln('Error: ${e.error.message}');
  }
  exitCode = 1;
}
