import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:alibaba_security_api/alibaba_security_api.dart';

import '../config/cli_config.dart';
import '../formatters/json_formatter.dart';
import '../formatters/table_formatter.dart';

/// `alsec vulns` — list and get vulnerabilities (C5, C6).
class VulnerabilitiesCommand extends Command<void> {
  @override
  final String name = 'vulns';

  @override
  final String description =
      'List vulnerabilities (C5) or get vulnerability details (C6).';

  final CliConfig config;

  VulnerabilitiesCommand(this.config) {
    addSubcommand(VulnsListCommand(config));
    addSubcommand(VulnsGetCommand(config));
  }
}

/// `alsec vulns list` — list vulnerabilities with optional filters.
class VulnsListCommand extends Command<void> {
  @override
  final String name = 'list';

  @override
  final String description =
      'List vulnerabilities detected by Security Center.';

  final CliConfig config;

  VulnsListCommand(this.config) {
    argParser
      ..addOption(
        'severity',
        abbr: 's',
        help: 'Filter by severity (low, medium, high, critical).',
      )
      ..addOption('asset-id', help: 'Filter by affected asset ID.')
      ..addOption(
        'type',
        abbr: 't',
        help: 'Filter by vulnerability type (cve, web_cms, app, system).',
      )
      ..addOption('page', help: 'Page number (default: 1).', defaultsTo: '1')
      ..addOption(
        'page-size',
        help: 'Page size (default: 20).',
        defaultsTo: '20',
      );
  }

  @override
  Future<void> run() async {
    final client = config.createClient();
    final service = SecurityCenterService(client);
    final jsonFmt = config.jsonOutput ? const JsonFormatter() : null;
    const tableFmt = TableFormatter();

    final severityStr = argResults!['severity'] as String?;
    final assetId = argResults!['asset-id'] as String?;
    final typeStr = argResults!['type'] as String?;
    final page = int.tryParse(argResults!['page'] as String) ?? 1;
    final pageSize = int.tryParse(argResults!['page-size'] as String) ?? 20;

    try {
      final vulns = await service.listVulnerabilities(
        severity: severityStr != null ? Severity.fromString(severityStr) : null,
        assetId: assetId,
        vulType: typeStr != null ? VulType.fromString(typeStr) : null,
        page: page,
        pageSize: pageSize,
      );

      if (jsonFmt != null) {
        jsonFmt.printList(vulns);
      } else {
        tableFmt.printTable(
          title: 'Vulnerabilities (page $page)',
          headers: ['Vul ID', 'Name', 'Severity', 'Type', 'Asset', 'Status'],
          rows: vulns
              .map(
                (v) => [
                  v.vulId,
                  _truncate(v.name, 35),
                  v.severity,
                  v.vulType,
                  v.assetId ?? '-',
                  v.status ?? '-',
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

/// `alsec vulns get <vulId>` — get vulnerability details.
class VulnsGetCommand extends Command<void> {
  @override
  final String name = 'get';

  @override
  final String description = 'Get detailed information about a vulnerability.';

  final CliConfig config;

  VulnsGetCommand(this.config);

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      stderr.writeln(
        'Error: vulId is required. Usage: alsec vulns get <vulId>',
      );
      exitCode = 64;
      return;
    }

    final vulId = rest.first;
    final client = config.createClient();
    final service = SecurityCenterService(client);
    final jsonFmt = config.jsonOutput ? const JsonFormatter() : null;
    const tableFmt = TableFormatter();

    try {
      final detail = await service.getVulnerabilityDetail(vulId);

      if (jsonFmt != null) {
        jsonFmt.print(detail);
      } else {
        tableFmt.printDetails({
          'Vul ID': detail.vulId,
          'Name': detail.name,
          'Severity': detail.severity,
          'Type': detail.vulType,
          'CVE ID': detail.cveId ?? '-',
          'Description': detail.description ?? '-',
          'Fix Suggestion': detail.fixSuggestion ?? '-',
          'Affected Versions': detail.affectedVersions.isEmpty
              ? '-'
              : detail.affectedVersions.join(', '),
        }, title: 'Vulnerability Detail');
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
