import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:alibaba_security_api/alibaba_security_api.dart';

import '../config/cli_config.dart';
import '../formatters/json_formatter.dart';
import '../formatters/table_formatter.dart';

/// `alsec alerts <eventId>` — list alerts for a security event (C4).
class AlertsCommand extends Command<void> {
  @override
  final String name = 'alerts';

  @override
  final String description =
      'List alerts grouped by source for a security event (C4).';

  final CliConfig config;

  AlertsCommand(this.config);

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      stderr.writeln(
        'Error: eventId is required. Usage: alsec alerts <eventId>',
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
      final result = await service.listAlertsForEvent(eventId);

      if (jsonFmt != null) {
        jsonFmt.print(result);
      } else {
        stdout.writeln('Alerts for event: $eventId');
        stdout.writeln();

        if (result.alertsBySource.isEmpty) {
          stdout.writeln('No alerts found.');
          return;
        }

        for (final entry in result.alertsBySource.entries) {
          tableFmt.printTable(
            title: entry.key,
            headers: ['Alert ID', 'Severity', 'Message', 'Rule', 'Time'],
            rows: entry.value
                .map(
                  (a) => [
                    a.alertId,
                    a.severity,
                    _truncate(a.message, 50),
                    a.ruleId ?? '-',
                    a.timestamp ?? '-',
                  ],
                )
                .toList(),
          );
        }
      }
    } on AlibabaApiError catch (e) {
      if (jsonFmt != null) {
        jsonFmt.print(e.toJson());
      } else {
        stderr.writeln('Error: ${e.error.message}');
      }
      exitCode = 1;
    }
  }
}

String _truncate(String s, int maxLen) =>
    s.length > maxLen ? '${s.substring(0, maxLen - 3)}...' : s;
