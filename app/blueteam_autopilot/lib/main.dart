import 'package:flutter/material.dart';

import 'api/backend_client.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Backend URL can be configured via environment or hardcoded for development.
  // For Flutter web, the backend must have CORS enabled (already configured
  // in alibaba_security_backend).
  const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:8080',
  );

  final backendClient = BackendClient(baseUrl: backendUrl);

  runApp(BlueTeamApp(backendClient: backendClient));
}
