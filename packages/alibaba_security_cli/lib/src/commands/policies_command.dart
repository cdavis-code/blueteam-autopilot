import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:alibaba_security_api/alibaba_security_api.dart';

import '../config/cli_config.dart';
import '../formatters/json_formatter.dart';
import '../formatters/table_formatter.dart';

/// `alsec policies` — list and execute response policies (C7, C8).
class PoliciesCommand extends Command<void> {
  @override
  final String name = 'policies';

  @override
  final String description =
      'List response policies (C7) or execute a policy (C8).';

  final CliConfig config;

  PoliciesCommand(this.config) {
    addSubcommand(PoliciesListCommand(config));
    addSubcommand(PoliciesExecuteCommand(config));
  }
}

/// `alsec policies list` — list response policies.
class PoliciesListCommand extends Command<void> {
  @override
  final String name = 'list';

  @override
  final String description = 'List response policies from Agentic SOC.';

  final CliConfig config;

  PoliciesListCommand(this.config) {
    argParser.addOption(
      'scope',
      help: 'Filter by scope (waf, all).',
      defaultsTo: 'all',
    );
  }

  @override
  Future<void> run() async {
    final client = config.createClient();
    final service = CloudSiemService(client);
    final jsonFmt = config.jsonOutput ? const JsonFormatter() : null;
    const tableFmt = TableFormatter();

    final scopeStr = argResults!['scope'] as String;
    final scope = PolicyScope.fromString(scopeStr);

    try {
      final policies = await service.listResponsePolicies(scope: scope);

      if (jsonFmt != null) {
        jsonFmt.printList(policies);
      } else {
        tableFmt.printTable(
          title: 'Response Policies',
          headers: ['Policy ID', 'Name', 'Action', 'Trigger', 'Enabled'],
          rows: policies
              .map(
                (p) => [
                  p.policyId,
                  _truncate(p.name, 35),
                  p.actionType ?? '-',
                  p.triggerType ?? '-',
                  p.isEnabled ? 'Yes' : 'No',
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

/// `alsec policies execute <policyId>` — execute a response policy.
class PoliciesExecuteCommand extends Command<void> {
  @override
  final String name = 'execute';

  @override
  final String description =
      'Execute a response policy against an event (destructive in real mode).';

  final CliConfig config;

  PoliciesExecuteCommand(this.config) {
    argParser
      ..addOption(
        'event-id',
        abbr: 'e',
        help: 'Event ID to apply the policy to.',
      )
      ..addFlag(
        'dry-run',
        help: 'Simulate execution without making state-changing API calls.',
        defaultsTo: true,
      );
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      stderr.writeln(
        'Error: policyId is required. Usage: alsec policies execute <policyId> [--event-id X]',
      );
      exitCode = 64;
      return;
    }

    final policyId = rest.first;
    final eventId = argResults!['event-id'] as String?;
    final dryRun = argResults!['dry-run'] as bool;

    final client = config.createClient();
    final service = CloudSiemService(client);
    final jsonFmt = config.jsonOutput ? const JsonFormatter() : null;

    try {
      final result = await service.executeResponsePolicy(
        policyId: policyId,
        eventId: eventId,
        dryRun: dryRun,
      );

      if (jsonFmt != null) {
        jsonFmt.print(result);
      } else {
        final modeLabel = result.mode == 'dry-run' ? '[DRY-RUN] ' : '';
        stdout.writeln('${modeLabel}Policy execution result:');
        stdout.writeln('  Policy ID: ${result.policyId}');
        if (result.eventId != null) {
          stdout.writeln('  Event ID:  ${result.eventId}');
        }
        stdout.writeln('  Mode:      ${result.mode}');
        stdout.writeln('  Result:    ${result.result}');
      }
    } on AlibabaApiError catch (e) {
      _handleError(e, jsonFmt);
    }
  }
}

String _truncate(String s, int maxLen) =>
    s.length > maxLen ? '${s.substring(0, maxLen - 3)}...' : s;

void _handleError(AlibabaApiError e, JsonFormatter? jsonFmt) {
  if (jsonFmt != null) {
    jsonFmt.print(e.toJson());
  } else {
    stderr.writeln('Error: ${e.error.message}');
  }
  exitCode = 1;
}
