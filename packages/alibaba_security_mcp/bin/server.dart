// Entry point for the Alibaba Security MCP server.
//
// After running `dart run build_runner build`, the generated
// `alibaba_security_server.mcp.dart` file will contain the full MCP server
// implementation. This file imports and runs it.
//
// Usage:
//   cd packages/alibaba_security_mcp
//   dart run build_runner build
//   dart run bin/server.dart
import 'package:alibaba_security_mcp/src/alibaba_security_server.mcp.dart'
    as generated;

Future<void> main(List<String> args) async {
  await generated.main();
}
