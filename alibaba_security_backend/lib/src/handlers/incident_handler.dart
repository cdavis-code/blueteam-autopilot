import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../repositories/incident_repository.dart';
import '../repositories/recommendation_repository.dart';

/// Incident CRUD handler.
///
/// - `GET /api/v1/incidents` — list incidents (filters: severity, status)
/// - `GET /api/v1/incidents/<id>` — get incident detail with recommendations
class IncidentHandler {
  final IncidentRepository _incidentRepo;
  final RecommendationRepository _recommendationRepo;

  IncidentHandler(this._incidentRepo, this._recommendationRepo);

  Router get router =>
      Router()
        ..get('/api/v1/incidents', _list)
        ..get('/api/v1/incidents/<id>', _getById);

  Future<Response> _list(Request request) async {
    final severity = request.url.queryParameters['severity'];
    final status = request.url.queryParameters['status'];
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 50;

    final incidents = await _incidentRepo.list(
      severity: severity,
      status: status,
      limit: limit,
    );

    return Response.ok(
      json.encode({
        'data': incidents.map((i) => i.toJson()).toList(),
        'error': null,
        'meta': {'total': incidents.length},
      }),
      headers: _jsonHeaders,
    );
  }

  Future<Response> _getById(Request request, String id) async {
    final incident = await _incidentRepo.getById(id);
    if (incident == null) {
      return Response.notFound(
        json.encode({
          'data': null,
          'error': {'code': 'NOT_FOUND', 'message': 'Incident $id not found.'},
        }),
        headers: _jsonHeaders,
      );
    }

    // Also fetch linked recommendations
    final recommendations = await _recommendationRepo.listForIncident(id);

    return Response.ok(
      json.encode({
        'data': {
          ...incident.toJson(),
          'recommendations':
              recommendations.map((r) => r.toJson()).toList(),
        },
        'error': null,
      }),
      headers: _jsonHeaders,
    );
  }
}

const _jsonHeaders = {'Content-Type': 'application/json'};
