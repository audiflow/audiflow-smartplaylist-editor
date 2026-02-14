import 'dart:convert';

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
///
/// Wraps the handler in a try-catch so that unhandled
/// errors still produce a response with CORS headers,
/// preventing the browser from masking the real error
/// behind a CORS-blocked "Failed to fetch".
Middleware corsMiddleware({String allowedOrigin = '*'}) {
  final corsHeaders = _buildCorsHeaders(allowedOrigin);

  return (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }
      try {
        final response = await handler(request);
        return response.change(headers: corsHeaders);
      } on Object catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders,
          },
        );
      }
    };
  };
}
