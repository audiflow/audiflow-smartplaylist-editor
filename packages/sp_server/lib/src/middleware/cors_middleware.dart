import 'package:shelf/shelf.dart';

/// CORS headers applied to all responses.
///
/// [allowedOrigin] controls which origins are permitted.
/// Defaults to `*` for development convenience.
Map<String, String> _buildCorsHeaders(String allowedOrigin) {
  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
    'Access-Control-Allow-Headers':
        'Origin, Content-Type, Accept, Authorization',
    'Access-Control-Max-Age': '86400',
  };
}

/// Middleware that adds CORS headers to every response
/// and handles OPTIONS preflight requests.
Middleware corsMiddleware({String allowedOrigin = '*'}) {
  final corsHeaders = _buildCorsHeaders(allowedOrigin);

  return (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }
      final response = await handler(request);
      return response.change(headers: corsHeaders);
    };
  };
}
