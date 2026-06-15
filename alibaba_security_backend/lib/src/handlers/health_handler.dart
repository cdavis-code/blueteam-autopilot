import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../config/backend_config.dart';

/// Health check handler.
///
/// `GET /health` returns server status, region, and configuration info.
class HealthHandler {
  final BackendConfig _config;

  HealthHandler(this._config);

  Router get router => Router()..get('/health', _health);

  Future<Response> _health(Request request) async {
    return Response.ok(
      json.encode({
        'data': {
          'status': 'ok',
          'region': _config.region,
          'tablestore': _config.hasTableStore ? 'configured' : 'in-memory',
          'qwen': _config.hasQwen ? 'configured' : 'not configured',
          'dryRun': _config.defaultDryRun,
        },
        'error': null,
      }),
      headers: _jsonHeaders,
    );
  }
}

const _jsonHeaders = {'Content-Type': 'application/json'};
