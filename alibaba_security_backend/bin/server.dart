import 'dart:io';

import 'package:alibaba_security_backend/alibaba_security_backend.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// BlueTeam Autopilot backend server entry point.
///
/// Reads configuration from environment variables and starts a Shelf HTTP
/// server. See [BackendConfig.fromEnvironment] for the full list of
/// supported environment variables.
Future<void> main() async {
  final config = BackendConfig.fromEnvironment();
  final server = BackendServer(config);

  final httpServer = await shelf_io.serve(
    server.handler,
    InternetAddress.anyIPv4,
    config.port,
  );

  stderr.writeln(
    'BlueTeam Autopilot backend listening on '
    'http://${httpServer.address.host}:${httpServer.port}',
  );
  stderr.writeln('Region: ${config.region}');
  stderr.writeln(
    'TableStore: ${config.hasTableStore ? "configured" : "in-memory"}',
  );
  stderr.writeln(
    'Qwen: ${config.hasQwen ? "configured (${config.qwenModel})" : "not configured"}',
  );
  stderr.writeln('Dry-run: ${config.defaultDryRun}');
}
