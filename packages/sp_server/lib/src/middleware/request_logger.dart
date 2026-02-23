import 'package:shelf/shelf.dart';

/// Log level for request logging.
enum LogLevel { debug, info }

/// Parses [value] into a [LogLevel], defaulting to [LogLevel.info].
LogLevel parseLogLevel(String? value) {
  if (value == null) return LogLevel.info;
  return switch (value.toLowerCase()) {
    'debug' => LogLevel.debug,
    _ => LogLevel.info,
  };
}

const _maxBodyLength = 2000;

/// Whether the HTTP [method] is a mutating (write) operation.
bool _isMutating(String method) {
  return switch (method) {
    'PUT' || 'POST' || 'DELETE' || 'PATCH' => true,
    _ => false,
  };
}

String _truncate(String text) {
  if (text.length <= _maxBodyLength) return text;
  return '${text.substring(0, _maxBodyLength)}... [truncated]';
}

/// Configurable request logging middleware.
///
/// At [LogLevel.info]: logs method, path, status, duration (same as shelf's
/// built-in `logRequests()`).
///
/// At [LogLevel.debug]: additionally logs request bodies for mutating
/// operations and response bodies for error responses (4xx/5xx).
Middleware requestLogger({LogLevel level = LogLevel.info}) {
  return (Handler handler) {
    return (Request request) async {
      final watch = Stopwatch()..start();
      final method = request.method;
      final path = request.requestedUri.path;

      // Read request body upfront at debug level for mutating requests
      String? requestBody;
      Request forwarded = request;
      if (level == LogLevel.debug && _isMutating(method)) {
        requestBody = await request.readAsString();
        // Reconstruct the request so downstream handlers can still read it
        forwarded = request.change(body: requestBody);
      }

      final Response response;
      try {
        response = await handler(forwarded);
      } on Object catch (error, stackTrace) {
        print('${watch.elapsed} $method $path ERROR $error');
        if (level == LogLevel.debug) {
          if (requestBody != null) {
            print('  [request body] ${_truncate(requestBody)}');
          }
          print('  [stack] $stackTrace');
        }
        rethrow;
      }

      final statusCode = response.statusCode;
      print('${watch.elapsed} $method $path $statusCode');

      if (level == LogLevel.debug) {
        if (requestBody != null) {
          print('  [request body] ${_truncate(requestBody)}');
        }
        // Log response body for error responses
        if (400 <= statusCode) {
          final responseBody = await response.readAsString();
          print('  [response body] ${_truncate(responseBody)}');
          // Reconstruct response since we consumed the body
          return response.change(body: responseBody);
        }
      }

      return response;
    };
  };
}
