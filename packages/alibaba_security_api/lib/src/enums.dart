/// Shared enumerations for the Alibaba Security API package.
library;

/// Severity level for security events, alerts, and vulnerabilities.
enum Severity {
  low,
  medium,
  high,
  critical;

  /// Parse a severity string (case-insensitive) into a [Severity] value.
  static Severity fromString(String value) {
    return Severity.values.firstWhere(
      (s) => s.name.toLowerCase() == value.toLowerCase(),
      orElse: () => Severity.medium,
    );
  }
}

/// Status of a security event in Agentic SOC.
enum EventStatus {
  /// Newly created event, not yet investigated.
  newEvent,

  /// Currently being investigated.
  inProgress,

  /// Event has been resolved or dismissed.
  resolved;

  /// Parse an event status string (case-insensitive) into an [EventStatus].
  static EventStatus fromString(String value) {
    final normalized = value.toLowerCase().replaceAll('_', '');
    return switch (normalized) {
      'new' || 'newevent' => EventStatus.newEvent,
      'inprogress' || 'processing' => EventStatus.inProgress,
      'resolved' || 'closed' => EventStatus.resolved,
      _ => EventStatus.newEvent,
    };
  }
}

/// Type of vulnerability detected by Security Center.
enum VulType {
  /// Common Vulnerabilities and Exposures.
  cve,

  /// Web CMS vulnerabilities.
  webCms,

  /// Application-level vulnerabilities.
  app,

  /// System / OS-level vulnerabilities.
  system;

  /// Parse a vulnerability type string (case-insensitive) into a [VulType].
  static VulType fromString(String value) {
    final normalized = value.toLowerCase().replaceAll('_', '');
    return switch (normalized) {
      'cve' => VulType.cve,
      'webcms' => VulType.webCms,
      'app' => VulType.app,
      'system' => VulType.system,
      _ => VulType.cve,
    };
  }
}

/// Execution mode for the MCP server and API client.
enum SecurityCenterMode {
  /// Simulate all mutating operations; never make state-changing API calls.
  dryRun,

  /// Execute real API calls that may change state.
  real;

  /// Parse a mode string (case-insensitive) into a [SecurityCenterMode].
  static SecurityCenterMode fromString(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll('-', '')
        .replaceAll('_', '');
    return switch (normalized) {
      'real' => SecurityCenterMode.real,
      _ => SecurityCenterMode.dryRun,
    };
  }
}

/// Scope filter for response policy listing.
enum PolicyScope {
  /// Only WAF-related response policies.
  waf,

  /// All response policies regardless of source.
  all;

  /// Parse a scope string (case-insensitive) into a [PolicyScope].
  static PolicyScope fromString(String value) {
    return value.toLowerCase() == 'waf' ? PolicyScope.waf : PolicyScope.all;
  }
}
