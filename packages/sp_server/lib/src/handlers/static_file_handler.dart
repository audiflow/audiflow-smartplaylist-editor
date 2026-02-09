import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

/// Creates a handler that serves static files from [webRoot].
///
/// Returns `null` when the [webRoot] directory does not exist,
/// allowing the server to run in API-only mode during development.
Handler? createStaticFileHandler(String webRoot) {
  final dir = Directory(webRoot);
  if (!dir.existsSync()) return null;

  return createStaticHandler(webRoot, defaultDocument: 'index.html');
}

/// Creates a handler that serves `index.html` for any path without
/// a file extension, enabling client-side (SPA) routing.
///
/// Returns `null` when the [webRoot] directory does not exist.
Handler? createSpaFallbackHandler(String webRoot) {
  final indexFile = File('$webRoot/index.html');
  if (!indexFile.existsSync()) return null;

  return (Request request) {
    final path = request.url.path;

    // Only fall back for paths that look like SPA routes
    // (no file extension = not a static asset request).
    if (!path.contains('.')) {
      return Response.ok(
        indexFile.readAsBytesSync(),
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      );
    }

    return Response.notFound('Not found');
  };
}
