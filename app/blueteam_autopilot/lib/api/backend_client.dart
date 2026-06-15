import 'package:dio/dio.dart';

import 'models/api_response.dart';
import 'models/incident_model.dart';
import 'models/recommendation_model.dart';

/// HTTP client for the BlueTeam Autopilot backend REST API.
///
/// Wraps all endpoints exposed by `IncidentHandler` and `AnalysisHandler`
/// in the `alibaba_security_backend` package.
class BackendClient {
  final Dio _dio;

  BackendClient({String baseUrl = 'http://localhost:8080', Dio? dio})
    : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl));

  // ---------------------------------------------------------------------------
  // Incidents
  // ---------------------------------------------------------------------------

  /// `GET /api/v1/incidents`
  Future<List<IncidentModel>> listIncidents({
    String? severity,
    String? status,
    int? limit,
  }) async {
    final params = <String, dynamic>{};
    if (severity != null) params['severity'] = severity;
    if (status != null) params['status'] = status;
    if (limit != null) params['limit'] = limit;

    final response = await _dio.get(
      '/api/v1/incidents',
      queryParameters: params,
    );

    final envelope = ApiResponse<List<IncidentModel>>.fromJson(
      response.data as Map<String, dynamic>,
      (data) => (data as List<dynamic>)
          .map((e) => IncidentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

    if (!envelope.isSuccess) {
      throw ApiException(envelope.error?.message ?? 'Failed to list incidents');
    }
    return envelope.data ?? [];
  }

  /// `GET /api/v1/incidents/<id>`
  ///
  /// Returns the incident merged with its recommendations.
  Future<IncidentDetailModel> getIncident(String id) async {
    final response = await _dio.get('/api/v1/incidents/$id');

    final envelope = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data as Map<String, dynamic>,
      (data) => data as Map<String, dynamic>,
    );

    if (!envelope.isSuccess) {
      throw ApiException(
        envelope.error?.message ?? 'Failed to get incident $id',
      );
    }

    final raw = envelope.data!;
    final incident = IncidentModel.fromJson(raw);

    // Extract recommendations from the merged response
    final recsJson = raw['recommendations'] as List<dynamic>? ?? [];
    final recommendations = recsJson
        .map((e) => RecommendationModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return IncidentDetailModel(
      incident: incident,
      recommendations: recommendations,
    );
  }

  // ---------------------------------------------------------------------------
  // Analysis
  // ---------------------------------------------------------------------------

  /// `POST /api/v1/incidents/analyze`
  Future<AnalysisResultModel> triggerAnalysis({
    String? minSeverity,
    int? maxEvents,
    String? timeRange,
  }) async {
    final body = <String, dynamic>{};
    if (minSeverity != null) body['minSeverity'] = minSeverity;
    if (maxEvents != null) body['maxEvents'] = maxEvents;
    if (timeRange != null) body['timeRange'] = timeRange;

    final response = await _dio.post('/api/v1/incidents/analyze', data: body);

    final envelope = ApiResponse<AnalysisResultModel>.fromJson(
      response.data as Map<String, dynamic>,
      (data) => AnalysisResultModel.fromJson(data as Map<String, dynamic>),
    );

    if (!envelope.isSuccess) {
      throw ApiException(envelope.error?.message ?? 'Analysis failed');
    }
    return envelope.data ?? const AnalysisResultModel();
  }

  // ---------------------------------------------------------------------------
  // Recommendation actions
  // ---------------------------------------------------------------------------

  /// `POST /api/v1/incidents/<incidentId>/recommendations/<recId>/approve`
  Future<void> approveRecommendation(String incidentId, String recId) async {
    await _dio.post(
      '/api/v1/incidents/$incidentId/recommendations/$recId/approve',
    );
  }

  /// `POST /api/v1/incidents/<incidentId>/recommendations/<recId>/reject`
  Future<void> rejectRecommendation(String incidentId, String recId) async {
    await _dio.post(
      '/api/v1/incidents/$incidentId/recommendations/$recId/reject',
    );
  }

  /// `POST /api/v1/incidents/<incidentId>/recommendations/<recId>/execute`
  Future<ExecutionResultModel> executeRecommendation(
    String incidentId,
    String recId, {
    bool dryRun = false,
  }) async {
    final response = await _dio.post(
      '/api/v1/incidents/$incidentId/recommendations/$recId/execute',
      data: {'dryRun': dryRun},
    );

    final envelope = ApiResponse<ExecutionResultModel>.fromJson(
      response.data as Map<String, dynamic>,
      (data) => ExecutionResultModel.fromJson(data as Map<String, dynamic>),
    );

    if (!envelope.isSuccess) {
      throw ApiException(envelope.error?.message ?? 'Execution failed');
    }
    return envelope.data ??
        ExecutionResultModel(recommendationId: recId, status: 'UNKNOWN');
  }
}

/// Combined incident + recommendations returned by the detail endpoint.
class IncidentDetailModel {
  final IncidentModel incident;
  final List<RecommendationModel> recommendations;

  const IncidentDetailModel({
    required this.incident,
    required this.recommendations,
  });
}

/// Exception thrown by [BackendClient] when an API call fails.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
