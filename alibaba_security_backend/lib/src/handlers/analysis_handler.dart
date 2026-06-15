import 'dart:convert';

import 'package:alibaba_security_api/alibaba_security_api.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../repositories/recommendation_repository.dart';
import '../services/analysis_service.dart';

/// Analysis orchestration handler.
///
/// - `POST /api/v1/incidents/analyze` — trigger AI analysis of latest events
/// - `POST /api/v1/vulnerabilities/analyze` — trigger vuln triage
/// - `POST /api/v1/incidents/<id>/recommendations/<recId>/approve` — approve
/// - `POST /api/v1/incidents/<id>/recommendations/<recId>/reject` — reject
/// - `POST /api/v1/incidents/<id>/recommendations/<recId>/execute` — execute
class AnalysisHandler {
  final AnalysisService _analysisService;
  final RecommendationRepository _recommendationRepo;

  AnalysisHandler(this._analysisService, this._recommendationRepo);

  Router get router =>
      Router()
        ..post('/api/v1/incidents/analyze', _analyzeIncidents)
        ..post('/api/v1/vulnerabilities/analyze', _analyzeVulnerabilities)
        ..post(
          '/api/v1/incidents/<incidentId>/recommendations/<recId>/approve',
          _approveRecommendation,
        )
        ..post(
          '/api/v1/incidents/<incidentId>/recommendations/<recId>/reject',
          _rejectRecommendation,
        )
        ..post(
          '/api/v1/incidents/<incidentId>/recommendations/<recId>/execute',
          _executeRecommendation,
        );

  Future<Response> _analyzeIncidents(Request request) async {
    // Parse optional body parameters
    Map<String, dynamic>? body;
    try {
      final raw = await request.readAsString();
      if (raw.isNotEmpty) {
        body = json.decode(raw) as Map<String, dynamic>;
      }
    } catch (_) {
      body = null;
    }

    final severityStr = body?['minSeverity'] as String?;
    final minSeverity =
        severityStr != null ? Severity.fromString(severityStr) : null;
    final maxEvents = body?['maxEvents'] as int?;
    final timeRangeStr = body?['timeRange'] as String?;
    final timeRange =
        timeRangeStr != null ? TimeWindow.fromRange(TimeRange.fromString(timeRangeStr)) : null;

    try {
      final result = await _analysisService.analyzeIncidents(
        timeRange: timeRange,
        minSeverity: minSeverity,
        maxEvents: maxEvents,
      );

      return Response.ok(
        json.encode({'data': result.toJson(), 'error': null}),
        headers: _jsonHeaders,
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({
          'data': null,
          'error': {'code': 'ANALYSIS_FAILED', 'message': e.toString()},
        }),
        headers: _jsonHeaders,
      );
    }
  }

  Future<Response> _analyzeVulnerabilities(Request request) async {
    Map<String, dynamic>? body;
    try {
      final raw = await request.readAsString();
      if (raw.isNotEmpty) {
        body = json.decode(raw) as Map<String, dynamic>;
      }
    } catch (_) {
      body = null;
    }

    final severityStr = body?['minSeverity'] as String?;
    final minSeverity =
        severityStr != null ? Severity.fromString(severityStr) : null;

    try {
      final result = await _analysisService.analyzeVulnerabilities(
        minSeverity: minSeverity,
      );

      return Response.ok(
        json.encode({'data': result.toJson(), 'error': null}),
        headers: _jsonHeaders,
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({
          'data': null,
          'error': {'code': 'VULN_ANALYSIS_FAILED', 'message': e.toString()},
        }),
        headers: _jsonHeaders,
      );
    }
  }

  Future<Response> _approveRecommendation(
    Request request,
    String incidentId,
    String recId,
  ) async {
    final rec = await _recommendationRepo.getById(recId);
    if (rec == null) {
      return Response.notFound(
        json.encode({
          'data': null,
          'error': {
            'code': 'NOT_FOUND',
            'message': 'Recommendation $recId not found.',
          },
        }),
        headers: _jsonHeaders,
      );
    }

    await _recommendationRepo.updateStatus(recId, 'APPROVED');

    return Response.ok(
      json.encode({
        'data': {'recommendationId': recId, 'status': 'APPROVED'},
        'error': null,
      }),
      headers: _jsonHeaders,
    );
  }

  Future<Response> _rejectRecommendation(
    Request request,
    String incidentId,
    String recId,
  ) async {
    await _recommendationRepo.updateStatus(recId, 'REJECTED');

    return Response.ok(
      json.encode({
        'data': {'recommendationId': recId, 'status': 'REJECTED'},
        'error': null,
      }),
      headers: _jsonHeaders,
    );
  }

  Future<Response> _executeRecommendation(
    Request request,
    String incidentId,
    String recId,
  ) async {
    // Parse optional body
    Map<String, dynamic>? body;
    try {
      final raw = await request.readAsString();
      if (raw.isNotEmpty) {
        body = json.decode(raw) as Map<String, dynamic>;
      }
    } catch (_) {
      body = null;
    }

    final dryRun = body?['dryRun'] as bool?;

    try {
      final result = await _analysisService.executeRecommendation(
        recId,
        dryRun: dryRun,
      );

      return Response.ok(
        json.encode({'data': result.toJson(), 'error': null}),
        headers: _jsonHeaders,
      );
    } on StateError catch (e) {
      return Response(
        400,
        body: json.encode({
          'data': null,
          'error': {'code': 'BAD_REQUEST', 'message': e.message},
        }),
        headers: _jsonHeaders,
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({
          'data': null,
          'error': {'code': 'EXECUTION_FAILED', 'message': e.toString()},
        }),
        headers: _jsonHeaders,
      );
    }
  }
}

const _jsonHeaders = {'Content-Type': 'application/json'};
