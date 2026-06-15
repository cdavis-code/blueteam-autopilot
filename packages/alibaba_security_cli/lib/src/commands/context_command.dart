import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:alibaba_security_api/alibaba_security_api.dart';

import '../config/cli_config.dart';
import '../formatters/json_formatter.dart';
import '../formatters/table_formatter.dart';

/// `alsec context` — show account and region context (C9).
class ContextCommand extends Command<void> {
  @override
  final String name = 'context';

  @override
  final String description =
      'Show account context: region, Security Center edition, Agentic SOC status (C9).';

  final CliConfig config;

  ContextCommand(this.config);

  @override
  Future<void> run() async {
    final client = config.createClient();
    final service = SecurityCenterService(client);
    final jsonFmt = config.jsonOutput ? const JsonFormatter() : null;
    const tableFmt = TableFormatter();

    try {
      final ctx = await service.getAccountContext();

      if (jsonFmt != null) {
        jsonFmt.print(ctx);
      } else {
        tableFmt.printDetails({
          'Region': ctx['region']?.toString() ?? '-',
          'Edition': ctx['securityCenterEdition']?.toString() ?? '-',
          'Agentic SOC': ctx['agenticSocEnabled'] == true
              ? 'Enabled'
              : 'Disabled',
          'Mode': ctx['mode']?.toString() ?? '-',
        }, title: 'Account Context');
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
