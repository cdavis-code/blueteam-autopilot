import 'package:shelf/shelf.dart';

/// CORS middleware that adds cross-origin headers to all responses.
///
/// Required so the web UI (hosted on a different origin) can call the
/// backend API.
Middleware corsMiddleware({
  String allowOrigin = '*',
  String allowMethods = 'GET, POST, PUT, DELETE, OPTIONS',
  String allowHeaders = 'Content-Type, Authorization',
}) {
  return (Handler innerHandler) {
    return (Request request) async {
      // Handle preflight OPTIONS requests
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders(allowOrigin, allowMethods, allowHeaders));
      }

      final response = await innerHandler(request);

      return response.change(
        headers: _corsHeaders(allowOrigin, allowMethods, allowHeaders),
      );
    };
  };
}

Map<String, String> _corsHeaders(
  String allowOrigin,
  String allowMethods,
  String allowHeaders,
) {
  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Methods': allowMethods,
    'Access-Control-Allow-Headers': allowHeaders,
    'Access-Control-Max-Age': '86400',
  };
}
