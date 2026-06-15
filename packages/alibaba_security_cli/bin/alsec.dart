import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:alibaba_security_cli/src/commands/alerts_command.dart';
import 'package:alibaba_security_cli/src/commands/context_command.dart';
import 'package:alibaba_security_cli/src/commands/events_command.dart';
import 'package:alibaba_security_cli/src/commands/ping_command.dart';
import 'package:alibaba_security_cli/src/commands/policies_command.dart';
import 'package:alibaba_security_cli/src/commands/vulnerabilities_command.dart';
import 'package:alibaba_security_cli/src/config/cli_config.dart';

Future<void> main(List<String> args) async {
  // Parse global flags first to determine json output mode
  var jsonOutput = false;
  final filteredArgs = <String>[];

  for (final arg in args) {
    if (arg == '--json' || arg == '-j') {
      jsonOutput = true;
    } else {
      filteredArgs.add(arg);
    }
  }

  // Load configuration
  final CliConfig config;
  try {
    config = CliConfig.load(jsonOutput: jsonOutput);
  } on StateError catch (e) {
    stderr.writeln('Configuration error: ${e.message}');
    exit(78); // EX_CONFIG
  }

  final runner =
      CommandRunner<void>(
          'alsec',
          'Alibaba Cloud Security Center CLI — query events, alerts, '
              'vulnerabilities, and response policies.',
        )
        ..argParser.addFlag(
          'json',
          abbr: 'j',
          help: 'Output results as JSON instead of formatted tables.',
          negatable: false,
        )
        ..addCommand(PingCommand(config))
        ..addCommand(EventsCommand(config))
        ..addCommand(AlertsCommand(config))
        ..addCommand(VulnerabilitiesCommand(config))
        ..addCommand(PoliciesCommand(config))
        ..addCommand(ContextCommand(config));

  try {
    await runner.run(filteredArgs);
  } on UsageException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln();
    stderr.writeln(e.usage);
    exit(64); // EX_USAGE
  }
}
