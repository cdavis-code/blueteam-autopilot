import 'package:alibaba_security_agent/alibaba_security_agent.dart';
import 'package:alibaba_security_api/alibaba_security_api.dart';

import '../config/backend_config.dart';
import '../repositories/incident_repository.dart';
import '../repositories/recommendation_repository.dart';
import 'qwen_client.dart';

/// Result of an incident analysis batch run.
class AnalysisResult {
  /// IDs of incidents created during this run.
  final List<String> incidentIds;

  /// IDs of incidents that were skipped (already existed).
  final List<String> skippedEventIds;

  /// Errors encountered for individual events (event ID → error message).
  final Map<String, String> errors;

  const AnalysisResult({
    required this.incidentIds,
    this.skippedEventIds = const [],
    this.errors = const {},
  });

  Map<String, dynamic> toJson() => {
        'incidentIds': incidentIds,
        'skippedEventIds': skippedEventIds,
        'errors': errors,
      };
}

/// Orchestrates the incident analysis flow:
/// 1. Fetch recent security events from Agentic SOC
/// 2. For each event, fetch alerts and available policies
/// 3. Send to Qwen for AI analysis
/// 4. Store incident reports and action proposals
class AnalysisService {
  final SecurityCenterService _securityCenter;
  final CloudSiemService _cloudSiem;
  final QwenClient _qwenClient;
  final IncidentRepository _incidentRepo;
  final RecommendationRepository _recommendationRepo;
  final BackendConfig _config;

  AnalysisService({
    required SecurityCenterService securityCenter,
    required CloudSiemService cloudSiem,
    required QwenClient qwenClient,
    required IncidentRepository incidentRepo,
    required RecommendationRepository recommendationRepo,
    required BackendConfig config,
  })  : _securityCenter = securityCenter,
        _cloudSiem = cloudSiem,
        _qwenClient = qwenClient,
        _incidentRepo = incidentRepo,
        _recommendationRepo = recommendationRepo,
        _config = config;

  /// Analyze recent security events and create incidents.
  ///
  /// Fetches events from the last [timeRange] window (default from config),
  /// filters by [minSeverity], and processes up to [maxEvents] events.
  Future<AnalysisResult> analyzeIncidents({
    TimeWindow? timeRange,
    Severity? minSeverity,
    int? maxEvents,
  }) async {
    final effectiveWindow =
        timeRange ?? TimeWindow.fromRange(TimeRange.fromString(_config.defaultTimeRange));
    final limit = maxEvents ?? _config.maxIncidentsPerBatch;

    // Fetch account context once
    final accountContext = await _securityCenter.getAccountContext();

    // Fetch recent events
    final events = await _securityCenter.listSecurityEvents(
      window: effectiveWindow,
      minSeverity: minSeverity,
    );

    // Fetch available policies once
    List<ResponsePolicy> policies;
    try {
      policies = await _cloudSiem.listResponsePolicies();
    } catch (_) {
      policies = [];
    }

    final incidentIds = <String>[];
    final skippedEventIds = <String>[];
    final errors = <String, String>{};

    for (final event in events.take(limit)) {
      try {
        // Check if we already have an incident for this event
        final existing = await _incidentRepo.findByEventId(event.eventId);
        if (existing != null) {
          skippedEventIds.add(event.eventId);
          continue;
        }

        // Fetch alerts for this event
        List<Alert> allAlerts;
        try {
          final alertsResult =
              await _securityCenter.listAlertsForEvent(event.eventId);
          allAlerts = alertsResult.alertsBySource.values.expand((a) => a).toList();
        } catch (_) {
          allAlerts = [];
        }

        // Send to Qwen for analysis
        final result = await _qwenClient.analyzeIncident(
          event: event,
          alerts: allAlerts,
          availablePolicies: policies,
          accountContext: accountContext,
        );

        // Store the incident report
        final incidentId = await _incidentRepo.create(result.report);
        incidentIds.add(incidentId);

        // Store action proposals as recommendations
        for (final proposal in result.proposals) {
          await _recommendationRepo.create(proposal, incidentId);
        }
      } catch (e) {
        errors[event.eventId] = e.toString();
      }
    }

    return AnalysisResult(
      incidentIds: incidentIds,
      skippedEventIds: skippedEventIds,
      errors: errors,
    );
  }

  /// Analyze vulnerabilities and produce a prioritization.
  Future<VulnerabilityPrioritization> analyzeVulnerabilities({
    Severity? minSeverity,
  }) async {
    final accountContext = await _securityCenter.getAccountContext();

    final vulnerabilities = await _securityCenter.listVulnerabilities(
      severity: minSeverity,
      pageSize: 50,
    );

    return _qwenClient.prioritizeVulnerabilities(
      vulnerabilities: vulnerabilities,
      accountContext: accountContext,
    );
  }

  /// Execute an approved recommendation.
  ///
  /// Verifies the recommendation status is APPROVED, then calls the
  /// appropriate Alibaba API via [CloudSiemService].
  Future<ExecuteResponseResult> executeRecommendation(
    String recommendationId, {
    bool? dryRun,
  }) async {
    final rec = await _recommendationRepo.getById(recommendationId);
    if (rec == null) {
      throw StateError('Recommendation $recommendationId not found.');
    }

    if (rec.status != 'APPROVED') {
      throw StateError(
        'Recommendation $recommendationId must be APPROVED before execution. '
        'Current status: ${rec.status}',
      );
    }

    final effectiveDryRun = dryRun ?? _config.defaultDryRun;

    try {
      final result = await _cloudSiem.executeResponsePolicy(
        policyId: rec.proposal.recommendedPolicyId,
        eventId: rec.proposal.eventId,
        dryRun: effectiveDryRun,
      );

      await _recommendationRepo.updateStatus(
        recommendationId,
        'APPLIED',
        executionLog: result.result,
      );

      return result;
    } catch (e) {
      await _recommendationRepo.updateStatus(
        recommendationId,
        'FAILED',
        executionLog: e.toString(),
      );
      rethrow;
    }
  }
}
