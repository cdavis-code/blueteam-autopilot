import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:alibaba_security_api/alibaba_security_api.dart';

import '../config/cli_config.dart';
import '../formatters/json_formatter.dart';

/// `alsec ping` — healthcheck command (C1).
///
/// Verifies that the API client can communicate with Alibaba Cloud
/// Security Center by calling DescribeVersionConfig.
class PingCommand extends Command<void> {
  @override
  final String name = 'ping';

  @override
  final String description =
      'Healthcheck: verify connectivity to Alibaba Cloud Security Center.';

  final CliConfig config;

  PingCommand(this.config);

  @override
  Future<void> run() async {
    final client = config.createClient();
    final service = SecurityCenterService(client);
    final jsonFmt = config.jsonOutput ? const JsonFormatter() : null;

    try {
      final ctx = await service.getAccountContext();

      if (jsonFmt != null) {
        jsonFmt.print({
          'ok': true,
          'region': ctx['region'],
          'mode': ctx['mode'],
          'securityCenterEdition': ctx['securityCenterEdition'],
          'agenticSocEnabled': ctx['agenticSocEnabled'],
        });
      } else {
        stdout.writeln('OK — connected to Alibaba Cloud Security Center');
        stdout.writeln('  Region:    ${ctx['region']}');
        stdout.writeln('  Mode:      ${ctx['mode']}');
        stdout.writeln('  Edition:   ${ctx['securityCenterEdition']}');
        stdout.writeln('  Agentic SOC: ${ctx['agenticSocEnabled']}');
      }
    } on AlibabaApiError catch (e) {
      if (jsonFmt != null) {
        jsonFmt.print(e.toJson());
      } else {
        stderr.writeln('FAIL — ${e.error.message}');
      }
      exitCode = 1;
    }
  }
}
