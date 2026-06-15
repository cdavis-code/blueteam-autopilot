/// Dart wrapper for Alibaba Cloud Security Center, Agentic SOC, and Cloud SIEM
/// APIs.
///
/// Provides clean interfaces for security events, alerts, vulnerabilities,
/// and response policies with request signing, pagination, and LLM-friendly
/// error handling.
library;

// Auth
export 'src/auth/alibaba_credentials.dart';
export 'src/auth/alibaba_signer.dart';

// Client
export 'src/client/alibaba_api_client.dart';

// Enums
export 'src/enums.dart';

// Models
export 'src/models/account_context.dart';
export 'src/models/alert.dart';
export 'src/models/error_envelope.dart';
export 'src/models/response_policy.dart';
export 'src/models/security_event.dart';
export 'src/models/vulnerability.dart';
export 'src/models/waf_security_event.dart';

// Services
export 'src/services/cloud_siem_service.dart';
export 'src/services/security_center_service.dart';
export 'src/services/waf_service.dart';

// Utilities
export 'src/util/time_window.dart';
